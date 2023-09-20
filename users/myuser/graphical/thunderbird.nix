{
  config,
  lib,
  nixosConfig,
  pkgs,
  ...
}: let
  rageWrapper = pkgs.writeShellScript "rage-decrypt-yubikey" ''
    export PATH="${pkgs.age-plugin-yubikey}:$PATH"
    exec ${pkgs.rage}/bin/rage
  '';
in {
  accounts.email.accounts =
    lib.flip lib.mapAttrs' config.userSecrets.accounts.email
    (_n: v:
      lib.nameValuePair v.address ({
          # TODO genericize
          passwordCommand =
            [rageWrapper.out "-d"]
            ++ lib.concatMap (x: ["-i" x]) nixosConfig.age.rekey.masterIdentities
            ++ [nixosConfig.age.secrets.mailpw-206fd3b8.path];

          thunderbird = {
            enable = true;
            profiles = ["personal"];
          };
        }
        // v));

  # TODO dont send html setting

  programs.thunderbird = {
    enable = true;

    profiles.personal = {
      isDefault = true;
      withExternalGnupg = true;

      settings = {
        "mail.identity.default.archive_enabled" = true;
        "mail.identity.default.archive_keep_folder_structure" = true;
        "mail.identity.default.compose_html" = false;
        "mail.identity.default.protectSubject" = true;
        "mail.identity.default.reply_on_top" = 1;
        "mail.identity.default.sig_on_reply" = false;

        "gfx.webrender.all" = true;
        "gfx.webrender.enabled" = true;

        "browser.display.use_system_colors" = true;
        "browser.theme.dark-toolbar-theme" = true;
      };
    };

    settings = {
      # Some general settings.
      "mail.server.default.allow_utf8_accept" = true;
      "mail.server.default.max_articles" = 1000;
      "mail.server.default.check_all_folders_for_new" = true;
      "mail.show_headers" = 1;

      # Show some metadata.
      "mailnews.headers.showMessageId" = true;
      "mailnews.headers.showOrganization" = true;
      "mailnews.headers.showReferences" = true;
      "mailnews.headers.showUserAgent" = true;

      # Sort mails and news in descending order.
      "mailnews.default_sort_order" = 2;
      "mailnews.default_news_sort_order" = 2;
      # Sort mails and news by date.
      "mailnews.default_sort_type" = 18;
      "mailnews.default_news_sort_type" = 18;

      # Sort them by the newest reply in thread.
      "mailnews.sort_threads_by_root" = true;
      # Show time.
      "mail.ui.display.dateformat.default" = 1;
      # Sanitize it to UTC to prevent leaking local time.
      "mail.sanitize_date_header" = true;

      # Email composing QoL.
      "mail.identity.default.auto_quote" = true;
      "mail.identity.default.attachPgpKey" = true;

      "app.update.auto" = false;
      "privacy.donottrackheader.enabled" = true;
    };
  };

  home.persistence."/state".directories = [
    ".cache/thunderbird"
  ];

  home.persistence."/persist".directories = [
    ".thunderbird"
  ];

  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/mailto" = ["thunderbird.desktop"];
    "message/rfc822" = ["thunderbird.desktop"];
  };
}
