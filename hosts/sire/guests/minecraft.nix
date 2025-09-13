# FIXME: todo: host the proxy on sentinel so the IPs are not lost in natting
{
  config,
  globals,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) getExe;

  minecraftDomain = "mc.${globals.domains.me}";
  dataDir = "/var/lib/minecraft";

  minecraft-attach = pkgs.writeShellApplication {
    name = "minecraft-attach";
    runtimeInputs = [ pkgs.tmux ];
    text = ''
      shopt -s nullglob

      [[ $EUID == 0 ]] || { echo "You have to be root (or use sudo) to attach to the console." >&2; exit 1; }

      SERVER_NAME="''${1-none}"
      TMUX_SOCKET="/run/minecraft-$1/tmux"

      if [[ ! -e "$TMUX_SOCKET" ]]; then
        echo "error: Unknown server name '$SERVER_NAME', or service not started." >&2
        AVAILABLE=("/run/minecraft-"*"/tmux")
        if [[ "''${#AVAILABLE[@]}" == 0 ]]; then
          echo "There are currently no servers available. Check your system services." >&2
        else
          avail=("''${AVAILABLE[@]#"/run/minecraft-"}")
          avail=("''${avail[@]%"/tmux"}")
          echo "Available servers: ''${avail[*]}" >&2
        fi
        exit 1
      fi

      exec runuser -u minecraft -- tmux -S "$TMUX_SOCKET" attach-session
    '';
  };

  helper-functions =
    # bash
    ''
      ################################################################
      # General helper functions

      function print_error() { echo "[1;31merror:[m $*" >&2; }
      function die() { print_error "$@"; exit 1; }

      function substatus() { echo "[32m$*[m"; }
      function datetime() { date "+%Y-%m-%d %H:%M:%S"; }
      function status_time() { echo "[1;33m[$(datetime)] [1m$*[m"; }

      function flush_stdin() {
        local empty_stdin
        # Unused variable is intentional.
        # shellcheck disable=SC2034
        while read -r -t 0.01 empty_stdin; do true; done
      }

      function ask() {
        local response
        while true; do
          flush_stdin
          read -r -p "$* (Y/n) " response || die "Error in read"
          case "''${response,,}" in
            "") return 0 ;;
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) continue ;;
          esac
        done
      }

      ################################################################
      # Download helper functions

      # $@: command to run as minecraft if user was changed.
      #     You want to pass path/to/curent/script.sh "$@".
      function become_minecaft() {
        if [[ $(id -un) != "minecraft" ]]; then
          if [[ $EUID == 0 ]] && ask "This script must be executed as the minecraft user. Change user and continue?"; then
            # shellcheck disable=SC2093
            exec runuser -u minecraft "$@"
            die "Could not change user!"
          else
            die "This script must be executed as the minecraft user!"
          fi
        fi
      }

      # $1: output file name
      function download_paper() {
        local paper_version
        local paper_build
        local paper_download
        paper_version="$(curl -s -o - "https://papermc.io/api/v2/projects/paper" | jq -r ".versions[-1]")" \
          || die "Error while retrieving paper version"
        paper_build="$(curl -s -o - "https://papermc.io/api/v2/projects/paper/versions/$paper_version" | jq -r ".builds[-1]")" \
          || die "Error while retrieving paper builds"
        paper_download="$(curl -s -o - "https://papermc.io/api/v2/projects/paper/versions/$paper_version/builds/$paper_build" | jq -r ".downloads.application.name")" \
          || die "Error while retrieving paper download name"

        substatus "Downloading paper version $paper_version build $paper_build ($paper_download)"
        wget -q --show-progress "https://papermc.io/api/v2/projects/paper/versions/$paper_version/builds/$paper_build/downloads/$paper_download" \
          -O "$1" \
          || die "Could not download paper"
      }

      # $1: output file name
      function download_velocity() {
        local velocity_version
        local velocity_build
        local velocity_download
        velocity_version="$(curl -s -o - "https://papermc.io/api/v2/projects/velocity" | jq -r ".versions[-1]")" \
          || die "Error while retrieving velocity version"
        velocity_build="$(curl -s -o - "https://papermc.io/api/v2/projects/velocity/versions/$velocity_version" | jq -r ".builds[-1]")" \
          || die "Error while retrieving velocity builds"
        velocity_download="$(curl -s -o - "https://papermc.io/api/v2/projects/velocity/versions/$velocity_version/builds/$velocity_build" | jq -r ".downloads.application.name")" \
          || die "Error while retrieving velocity download name"

        substatus "Downloading velocity version $velocity_version build $velocity_build ($velocity_download)"
        wget -q --show-progress "https://papermc.io/api/v2/projects/velocity/versions/$velocity_version/builds/$velocity_build/downloads/$velocity_download" \
          -O "$1" \
          || die "Could not download velocity"
      }

      # $1: repo, e.g. "oddlama/vane"
      declare -A LATEST_GITHUB_RELEASE_TAG_CACHE
      function latest_github_release_tag() {
        local repo=$1
        if [[ ! -v "LATEST_GITHUB_RELEASE_TAG_CACHE[$repo]" ]]; then
          local tmp
          tmp=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | jq -r .tag_name) \
            || die "Error while retrieving latest github release tag of $repo"
          LATEST_GITHUB_RELEASE_TAG_CACHE[$repo]="$tmp"
        fi
        echo "''${LATEST_GITHUB_RELEASE_TAG_CACHE[$repo]}"
      }

      # $1: repo, e.g. "oddlama/vane"
      # $2: remote file name.
      #     {TAG} will be replaced with the release tag
      #     {VERSION} will be replaced with release tag excluding a leading v, if present
      # $3: output file name
      function download_latest_github_release() {
        local repo=$1
        local remote_file=$2
        local output=$3

        local tag
        tag=$(latest_github_release_tag "$repo")
        local version="''${tag#v}" # Always strip leading v in version.

        remote_file="''${remote_file//"{TAG}"/"$tag"}"
        remote_file="''${remote_file//"{VERSION}"/"$version"}"

        wget -q --show-progress "https://github.com/$repo/releases/download/$tag/$remote_file" -O "$output" \
          || die "Could not download $remote_file from github repo $repo"
      }

      # $1: url
      # $2: output file name
      function download_file() {
        wget -q --show-progress "$1" -O "$2" || die "Could not download $1"
      }
    '';

  server-backup-script = pkgs.writeShellApplication {
    name = "minecraft-backup";
    runtimeInputs = [ pkgs.rdiff-backup ];
    text = ''
      BACKUP_LOG_FILE="logs/backup.log"
      BACKUP_TO="backups"
      BACKUP_DIRS=(
      	'plugins'
      	'world'
      	'world_nether'
      	'world_the_end'
      )

      cd ${dataDir}/server || exit 1
      ${helper-functions}

      status_time "Starting backup"

      mkdir -p "$BACKUP_TO" &>/dev/null
      for i in "''${!BACKUP_DIRS[@]}"; do
      	status_time "Backing up ''${BACKUP_DIRS[$i]}" | tee -a "$BACKUP_LOG_FILE"
      	rdiff-backup "''${BACKUP_DIRS[$i]}" "$BACKUP_TO/''${BACKUP_DIRS[$i]}" &>> "$BACKUP_LOG_FILE"
      done

      status_time "Backup finished" | tee -a "$BACKUP_LOG_FILE"
    '';
  };

  server-start-script = pkgs.writeShellApplication {
    name = "minecraft-server-start";
    runtimeInputs = [
      pkgs.procps
      pkgs.gnugrep
    ];
    text = ''
      cd ${dataDir}/server

      # Update velocity secret
      VELOCITY_SECRET="$(cat ../proxy/forwarding.secret)" \
        ${getExe pkgs.yq-go} -i '.proxies.velocity.secret = strenv(VELOCITY_SECRET)' \
        config/paper-global.yml

      # Use 80% of RAM, but not more than 12GiB and not less than 1GiB
      total_ram_gibi=$(free -g | grep -oP '\d+' | head -n1)
      ram="$((total_ram_gibi * 8 / 10))"
      [[ "$ram" -le 8 ]] || ram=8
      [[ "$ram" -ge 1 ]] || ram=1

      echo "[1;33mExecuting server using ''${ram}GiB of RAM[m"
      exec ${getExe pkgs.temurin-jre-bin} -Xms''${ram}G -Xmx''${ram}G \
      	-XX:+UseG1GC \
      	-XX:+ParallelRefProcEnabled \
      	-XX:MaxGCPauseMillis=200 \
      	-XX:+UnlockExperimentalVMOptions \
      	-XX:+DisableExplicitGC \
      	-XX:+AlwaysPreTouch \
      	-XX:G1NewSizePercent=30 \
      	-XX:G1MaxNewSizePercent=40 \
      	-XX:G1HeapRegionSize=8M \
      	-XX:G1ReservePercent=20 \
      	-XX:G1HeapWastePercent=5 \
      	-XX:G1MixedGCCountTarget=4 \
      	-XX:InitiatingHeapOccupancyPercent=15 \
      	-XX:G1MixedGCLiveThresholdPercent=90 \
      	-XX:G1RSetUpdatingPauseTimePercent=5 \
      	-XX:SurvivorRatio=32 \
      	-XX:+PerfDisableSharedMem \
      	-XX:MaxTenuringThreshold=1 \
      	-Dusing.aikars.flags=https://mcflags.emc.gs \
      	-Daikars.new.flags=true \
      	-jar paper.jar nogui
    '';
  };

  proxy-start-script = pkgs.writeShellApplication {
    name = "minecraft-proxy-start";
    text = ''
      cd ${dataDir}/proxy

      echo "[1;33mExecuting proxy server[m"
      exec ${getExe pkgs.temurin-jre-bin} -Xms1G -Xmx1G -XX:+UseG1GC -XX:G1HeapRegionSize=4M -XX:+UnlockExperimentalVMOptions -XX:+ParallelRefProcEnabled -XX:+AlwaysPreTouch -XX:MaxInlineLevel=15 -jar velocity.jar
    '';
  };

  server-update-script = pkgs.writeShellApplication {
    name = "minecraft-server-update";
    runtimeInputs = [
      pkgs.wget
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      cd ${dataDir}/server || exit 1
      ${helper-functions}
      become_minecaft "./update.sh"

      ################################################################
      # Download paper and prepare plugins

      download_paper paper.jar

      # Create plugins directory
      mkdir -p plugins \
      	|| die "Could not create directory 'plugins'"
      # Create optional plugins directory
      mkdir -p plugins/optional \
      	|| die "Could not create directory 'plugins/optional'"

      ################################################################
      # Download plugins

      substatus "Downloading plugins"
      for module in admin bedtime core enchantments permissions portals regions trifles; do
      	download_latest_github_release "oddlama/vane" "vane-$module-{VERSION}.jar" "plugins/vane-$module.jar"
      done

      download_file "https://ci.dmulloy2.net/job/ProtocolLib/lastSuccessfulBuild/artifact/build/libs/ProtocolLib.jar" plugins/ProtocolLib.jar
      download_latest_github_release "BlueMap-Minecraft/BlueMap" "BlueMap-{VERSION}-spigot.jar" plugins/bluemap.jar
    '';
  };

  proxy-update-script = pkgs.writeShellApplication {
    name = "minecraft-proxy-update";
    runtimeInputs = [
      pkgs.wget
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      cd ${dataDir}/proxy || exit 1
      ${helper-functions}
      become_minecaft "./update.sh"

      ################################################################
      # Download velocity and prepare plugins

      download_velocity velocity.jar

      # Create plugins directory
      mkdir -p plugins \
      	|| die "Could not create directory 'plugins'"

      ################################################################
      # Download plugins

      substatus "Downloading plugins"
      download_latest_github_release "oddlama/vane" "vane-velocity-{VERSION}.jar" "plugins/vane-velocity.jar"
    '';
  };

  commonServiceConfig = {
    Restart = "on-failure";
    User = "minecraft";

    # Hardening
    AmbientCapabilities = [ "CAP_KILL" ];
    CapabilityBoundingSet = [ "CAP_KILL" ];
    LockPersonality = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateTmp = true;
    PrivateUsers = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectProc = "invisible";
    ProtectSystem = "strict";
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    UMask = "0027";
  };
in
{
  microvm.mem = 1024 * 24;
  microvm.vcpu = 16;

  globals.wireguard.proxy-sentinel.hosts.${config.node.name}.firewallRuleForNode.sentinel.allowedTCPPorts =
    [
      80
      25565
      25566
    ];

  users.groups.minecraft.members = [ "nginx" ];
  users.users.minecraft = {
    description = "Minecraft server service user";
    home = dataDir;
    isSystemUser = true;
    group = "minecraft";
  };

  environment.persistence."/persist".directories = [
    {
      directory = dataDir;
      user = "minecraft";
      group = "minecraft";
      mode = "0750";
    }
  ];

  globals.services.minecraft.domain = minecraftDomain;
  globals.monitoring.tcp.minecraft = {
    host = minecraftDomain;
    port = 25565;
    network = "internet";
  };
  globals.monitoring.http.minecraft-map = {
    url = "https://${minecraftDomain}";
    expectedBodyRegex = "Minecraft Dynamic Map";
    network = "internet";
  };

  nodes.sentinel = {
    # Rewrite destination addr with dnat on incoming connections
    # and masquerade responses to make them look like they originate from this host.
    # - 25565,25566 (wan) -> 25565,25566 (proxy-sentinel)
    networking.nftables.chains = {
      postrouting.to-minecraft = {
        after = [ "hook" ];
        rules = [
          "iifname wan ip daddr ${
            globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4
          } tcp dport 25565 masquerade random"
          "iifname wan ip6 daddr ${
            globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv6
          } tcp dport 25565 masquerade random"
          "iifname wan ip daddr ${
            globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4
          } tcp dport 25566 masquerade random"
          "iifname wan ip6 daddr ${
            globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv6
          } tcp dport 25566 masquerade random"
        ];
      };
      prerouting.to-minecraft = {
        after = [ "hook" ];
        rules = [
          "iifname wan tcp dport 25565 dnat ip to ${
            globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4
          }"
          "iifname wan tcp dport 25565 dnat ip6 to ${
            globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv6
          }"
          "iifname wan tcp dport 25566 dnat ip to ${
            globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4
          }"
          "iifname wan tcp dport 25566 dnat ip6 to ${
            globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv6
          }"
        ];
      };
    };

    services.nginx = {
      upstreams.minecraft = {
        servers."${globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4}:80" = { };
        extraConfig = ''
          zone minecraft 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "Minecraft Dynamic Map";
        };
      };
      virtualHosts.${minecraftDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://minecraft";
        };
      };
    };
  };

  systemd.services.minecraft-server = {
    description = "Minecraft Server Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = [
      # for infocmp
      pkgs.ncurses
      # for dynmap
      pkgs.libwebp
    ];

    serviceConfig = commonServiceConfig // {
      Type = "forking";
      ExecStart = ''${getExe pkgs.tmux} -S /run/minecraft-server/tmux set -g default-shell ${getExe pkgs.bashInteractive} ";" new-session -d "${getExe pkgs.python3} ${./minecraft/server-loop.py} --block control/start.block ./start.sh :POST: ./backup.sh"'';
      ExecStop = "${getExe pkgs.tmux} -S /run/minecraft-server/tmux kill-server";

      WorkingDirectory = "${dataDir}/server";
      RuntimeDirectory = "minecraft-server";
      ReadWritePaths = [
        "${dataDir}/server"
        "${dataDir}/web"
      ];
      ReadOnlyPaths = "${dataDir}/proxy";
    };

    preStart = ''
      ln -sfT ${getExe server-start-script} start.sh
      ln -sfT ${getExe server-backup-script} backup.sh
      ln -sfT ${getExe server-update-script} update.sh

      function copyFile() {
        cp "$1" "$2"
        chmod 600 "$2"
      }

      copyFile ${./minecraft/server/eula.txt} eula.txt
      copyFile ${./minecraft/server/server.properties} server.properties
      copyFile ${./minecraft/server/spigot.yml} spigot.yml
      copyFile ${./minecraft/server/commands.yml} commands.yml
      mkdir -p config
      copyFile ${./minecraft/server/config/paper-global.yml} config/paper-global.yml
      copyFile ${./minecraft/server/config/paper-world-defaults.yml} config/paper-world-defaults.yml

      if [[ ! -e paper.jar ]]; then
        ./update.sh
      fi
    '';
  };

  systemd.services.minecraft-proxy = {
    description = "Minecraft Proxy Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = [ pkgs.ncurses ]; # for infocmp

    serviceConfig = commonServiceConfig // {
      Type = "forking";
      ExecStart = ''${getExe pkgs.tmux} -S /run/minecraft-proxy/tmux set -g default-shell ${getExe pkgs.bashInteractive} ";" new-session -d "${getExe pkgs.python3} ${./minecraft/server-loop.py} ./start.sh"'';
      ExecStop = "${getExe pkgs.tmux} -S /run/minecraft-proxy/tmux kill-server";

      WorkingDirectory = "${dataDir}/proxy";
      RuntimeDirectory = "minecraft-proxy";
      ReadWritePaths = [
        "${dataDir}/proxy"
        "${dataDir}/server/control"
      ];
    };

    preStart = ''
      ln -sfT ${getExe proxy-start-script} start.sh
      ln -sfT ${getExe proxy-update-script} update.sh

      function copyFile() {
        cp "$1" "$2"
        chmod 600 "$2"
      }

      copyFile ${./minecraft/proxy/velocity.toml} velocity.toml
      mkdir -p plugins/vane-velocity
      copyFile ${./minecraft/proxy/plugins/vane-velocity/config.toml} plugins/vane-velocity/config.toml

      if [[ ! -e velocity.jar ]]; then
        ./update.sh
      fi
    '';
  };

  systemd.tmpfiles.settings."50-minecraft" = {
    "${dataDir}".d = {
      user = "minecraft";
      mode = "0750";
    };
    "${dataDir}/server".d = {
      user = "minecraft";
      mode = "0700";
    };
    "${dataDir}/server/control".d = {
      user = "minecraft";
      mode = "0700";
    };
    "${dataDir}/proxy".d = {
      user = "minecraft";
      mode = "0700";
    };
    "${dataDir}/web".d = {
      user = "minecraft";
      mode = "0750";
    };
  };

  environment.systemPackages = [
    minecraft-attach
  ];

  services.phpfpm.pools.dynmap = {
    user = "nginx";
    group = "nginx";
    phpPackage = pkgs.php82;
    phpOptions = ''
      error_log = 'stderr'
      log_errors = on
    '';
    settings = {
      "listen.owner" = "nginx";
      "listen.group" = "nginx";
      "listen.mode" = "0660";
      "pm" = "dynamic";
      "pm.max_children" = 75;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 20;
      "pm.max_requests" = 500;
      "catch_workers_output" = true;
    };
  };

  services.nginx = {
    enable = true;
    recommendedSetup = false;
    virtualHosts.${minecraftDomain} = {
      root = "${dataDir}/web/dynmap";
      locations."~ \\.php$".extraConfig = ''
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:${config.services.phpfpm.pools.dynmap.socket};
        include ${config.services.nginx.package}/conf/fastcgi.conf;
        include ${config.services.nginx.package}/conf/fastcgi_params;
      '';
    };
  };
}
