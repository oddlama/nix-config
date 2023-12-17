{
  config,
  lib,
  ...
}: {
  # IP addresses: ${"${interface} \e{halfbright}\4{${interface}}\e{reset} \e{halfbright}\6{${interface}}\e{reset}"}
  environment.etc.issue.text = lib.concatStringsSep "\n" ([
      ''\d  \t''
      ''This is \e{cyan}\n\e{reset} [\e{lightblue}\l\e{reset}] (\s \m \r)''
    ]
    # Disabled for guests because of frequent redraws (-> pushed to syslog on the host)
    ++ lib.optional (config.node.type == "host") ''\e{halfbright}\4\e{reset} \e{halfbright}\6\e{reset}''
    ++ [""]);
}
