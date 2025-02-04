defmodule Provision do
  alias Domain.{Repo, Accounts, Auth, Actors}
  require Logger

  defp resolve_references(value) when is_map(value) do
    Enum.into(value, %{}, fn {k, v} -> {k, resolve_references(v)} end)
  end

  defp resolve_references(value) when is_list(value) do
    Enum.map(value, &resolve_references/1)
  end

  defp resolve_references(value) when is_binary(value) do
    Regex.replace(~r/\{env:([^}]+)\}/, value, fn _, var ->
      System.get_env(var) || raise "Environment variable #{var} not set"
    end)
  end

  defp resolve_references(value), do: value

  defp atomize_keys(map) when is_map(map) do
    Enum.into(map, %{}, fn {k, v} ->
      {
        if(is_binary(k), do: String.to_atom(k), else: k),
        if(is_map(v), do: atomize_keys(v), else: v)
      }
    end)
  end

  def provision() do
    IO.inspect("Starting provisioning", label: "INFO")
    json_file = "provision-state.json"
    {:ok, raw_json} = File.read(json_file)
    {:ok, %{"accounts" => accounts}} = Jason.decode(raw_json)
    accounts = resolve_references(accounts)

    multi = Enum.reduce(accounts, Ecto.Multi.new(), fn {slug, account_data}, multi ->
      account_attrs = atomize_keys(%{
        name: account_data["name"],
        slug: slug,
        features: Map.get(account_data, "features", %{}),
        metadata: Map.get(account_data, "metadata", %{}),
        limits: Map.get(account_data, "limits", %{}),
      })

      multi = multi
        |> Ecto.Multi.run({:account, slug}, fn repo, _changes ->
          case Accounts.fetch_account_by_id_or_slug(slug) do
            {:ok, acc} ->
              IO.inspect("Updating existing account #{slug}", label: "INFO")
              updated_acc = acc |> Ecto.Changeset.change(account_attrs) |> repo.update!()
              {:ok, {:existing, updated_acc}}
            _ ->
              IO.inspect("Creating new account #{slug}", label: "INFO")
              {:ok, account} = Accounts.create_account(account_attrs)
              {:ok, {:new, account}}
          end
        end)
        |> Ecto.Multi.run({:everyone_group, slug}, fn _repo, changes ->
          case Map.get(changes, {:account, slug}) do
            {:new, account} ->
              IO.inspect("Creating Everyone group for new account", label: "INFO")
              Actors.create_managed_group(account, %{name: "Everyone", membership_rules: [%{operator: true}]})
            {:existing, _account} ->
              {:ok, :skipped}
          end
        end)
        |> Ecto.Multi.run({:provider, slug}, fn _repo, changes ->
          case Map.get(changes, {:account, slug}) do
            {:new, account} ->
              IO.inspect("Creating default email provider for new account", label: "INFO")
              Auth.create_provider(account, %{name: "Email", adapter: :email, adapter_config: %{}})
            {:existing, account} ->
              Auth.Provider.Query.not_disabled()
              |> Auth.Provider.Query.by_adapter(:email)
              |> Auth.Provider.Query.by_account_id(account.id)
              |> Repo.fetch(Auth.Provider.Query, [])
          end
        end)

      multi = Enum.reduce(account_data["actors"] || %{}, multi, fn {name, actor_data}, multi ->
        actor_attrs = atomize_keys(%{
          name: name,
          type: String.to_atom(actor_data["type"]),
        })

        Ecto.Multi.run(multi, {:actor, slug, name}, fn repo, changes ->
          {_, account} = changes[{:account, slug}]
          case Repo.get_by(Actors.Actor, account_id: account.id, name: name) do
            nil ->
              IO.inspect("Creating new actor #{name}", label: "INFO")
              {:ok, actor} = Actors.create_actor(account, actor_attrs)
              {:ok, {:new, actor}}
            act ->
              IO.inspect("Updating existing actor #{name}", label: "INFO")
              updated_act = act |> Ecto.Changeset.change(actor_attrs) |> repo.update!()
              {:ok, {:existing, updated_act}}
          end
        end)
        |> Ecto.Multi.run({:actor_identity, slug, name}, fn repo, changes ->
          email_provider = changes[{:provider, slug}]
          case Map.get(changes, {:actor, slug, name}) do
            {:new, actor} ->
              IO.inspect("Creating actor email identity", label: "INFO")
              Auth.create_identity(actor, email_provider, %{
                provider_identifier: actor_data["email"],
                provider_identifier_confirmation: actor_data["email"]
              })
            {:existing, actor} ->
              IO.inspect("Updating actor email identity", label: "INFO")
              {:ok, identity} = Auth.Identity.Query.not_deleted()
              |> Auth.Identity.Query.by_actor_id(actor.id)
              |> Auth.Identity.Query.by_provider_id(email_provider.id)
              |> Repo.fetch(Auth.Identity.Query, [])

              {:ok, identity |> Ecto.Changeset.change(%{
                provider_identifier: actor_data["email"],
              }) |> repo.update!()}
          end
        end)
      end)

      multi = Enum.reduce(account_data["auth"] || %{}, multi, fn {name, provider_data}, multi ->
        provider_attrs = %{
          name: name,
          adapter: String.to_atom(provider_data["adapter"]),
          adapter_config: provider_data["adapter_config"],
        }

        Ecto.Multi.run(multi, {:provider, slug, name}, fn repo, changes ->
          {_, account} = changes[{:account, slug}]
          case Repo.get_by(Auth.Provider, account_id: account.id, name: name) do
            nil ->
              IO.inspect("Creating new provider #{name}", label: "INFO")
              Auth.create_provider(account, provider_attrs)
            existing ->
              IO.inspect("Updating existing provider #{name}", label: "INFO")
              {:ok, existing |> Ecto.Changeset.change(provider_attrs) |> repo.update!()}
          end
        end)
      end)

      multi
    end)

    case Repo.transaction(multi) do
      {:ok, _result} ->
        Logger.info("Provisioning completed successfully.")
      {:error, step, reason, _changes} ->
        Logger.error("Provisioning failed at step #{inspect(step)}: #{inspect(reason)}")
    end
  end
end

Provision.provision()
