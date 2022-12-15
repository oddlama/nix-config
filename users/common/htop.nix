{config, ...}: {
  programs.htop = {
    enable = true;
    settings =
      {
        highlight_base_name = 1;
        show_cpu_frequency = 1;
        show_cpu_temperature = 1;
        hide_kernel_threads = 1;
        hide_userland_threads = 1;
      }
      // (with config.lib.htop;
        leftMeters [
          (bar "LeftCPUs2")
          (bar "Memory")
          (bar "Swap")
          (bar "ZFSARC")
          (text "NetworkIO")
        ])
      // (with config.lib.htop;
        rightMeters [
          (bar "RightCPUs2")
          (text "LoadAverage")
          (text "Tasks")
          (text "Uptime")
          (text "Systemd")
        ]);
  };
}
