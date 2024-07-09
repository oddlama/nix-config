{
  lib,
  pkgs,
  nixosConfig,
  ...
}: let
  save-replay = pkgs.writeShellApplication {
    name = "gpu-screen-recorder-save-replay";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.systemd
    ];
    text = ''
      # sytemctl itself may return 0 if the service is not running / unit doesn't exist
      MAIN_PID=$(systemctl --user show --property MainPID --value gpu-screen-recorder.service || echo 0)
      if [[ "$MAIN_PID" -gt 0 ]]; then
        kill -USR1 "$MAIN_PID"

        notify-send '🎥 GPU Screen Recorder' '💾 Replay saved!' \
          -t 3000 \
          -i com.dec05eba.gpu_screen_recorder \
          -a 'GPU Screen Recorder'

        # Remember active window
        hyprctl activewindow -j > "$HOME/Videos/Replay_$(date +"%Y-%m-%d_%H-%M-%S.window.json")"
      else
        notify-send '🎥 GPU Screen Recorder' '❌ Cannot save replay, service not running' \
          -t 5000 \
          -i com.dec05eba.gpu_screen_recorder \
          -a 'GPU Screen Recorder'
      fi
    '';
  };

  on-stop-service = pkgs.writeShellApplication {
    name = "gpu-screen-recorder-stop-service";
    runtimeInputs = [pkgs.libnotify];
    text = ''
      if [[ "$SERVICE_RESULT" == "success" ]]; then
        notify-send '🎥 GPU Screen Recorder' '🔴 Replay service stopped!' \
          -t 5000 -u low \
          -i com.dec05eba.gpu_screen_recorder \
          -a 'GPU Screen Recorder'
      else
        notify-send '🎥 GPU Screen Recorder' '❌ Replay service failed: '"$EXIT_STATUS (code $EXIT_CODE)"'!' \
          -t 5000 \
          -i com.dec05eba.gpu_screen_recorder \
          -a 'GPU Screen Recorder'
      fi
    '';
  };

  start-service = pkgs.writeShellApplication {
    name = "gpu-screen-recorder-start-service";
    runtimeInputs = [
      pkgs.pulseaudio
      pkgs.libnotify
    ];
    text = ''
      AUDIO_SINK="$(pactl get-default-sink).monitor"
      AUDIO_SOURCE="$(pactl get-default-source)"

      # Always search in sources since we added .monitor to any sinks already
      AUDIO_SINK_DESC="$(pactl --format json list sources | jq -r '(.[] | select(.name == $NAME)).description' --arg NAME "$AUDIO_SINK")"
      AUDIO_SOURCE_DESC="$(pactl --format json list sources | jq -r '(.[] | select(.name == $NAME)).description' --arg NAME "$AUDIO_SOURCE")"

      notify-send '🎥 GPU Screen Recorder' '🟢 Replay started'$'\n'$'\n'"→ $AUDIO_SINK_DESC"$'\n'"→ $AUDIO_SOURCE_DESC" \
        -t 5000 -u low \
        -i com.dec05eba.gpu_screen_recorder \
        -a 'GPU Screen Recorder'

      exec /run/wrappers/bin/gpu-screen-recorder \
        -w "$GSR_WINDOW" \
        -c "$GSR_CONTAINER" \
        -q "$GSR_QUALITY" \
        -f "$GSR_FRAMERATE" \
        -fm "$GSR_MODE" \
        -k "$GSR_CODEC" \
        -ac "$GSR_AUDIO_CODEC" \
        -r "$GSR_REPLAYDURATION" \
        -v "$GSR_FPSPPS" \
        -mf "$GSR_MAKEFOLDERS" \
        -a "audio-out/$AUDIO_SINK" \
        -a "microphone/$AUDIO_SOURCE" \
        -o "$GSR_OUTPUTDIR"
    '';
  };
in {
  lib.gpu-screen-recorder = {
    inherit save-replay;
  };

  systemd.user.services.gpu-screen-recorder = {
    #Install.WantedBy = ["graphical-session.target"];
    Unit = {
      Description = "GPU Screen Recorder Service";
      #PartOf = ["graphical-session.target"];
    };
    Service = {
      Environment =
        [
          "GSR_CONTAINER=mkv"
          "GSR_QUALITY=ultra"
          "GSR_FRAMERATE=144"
          "GSR_MODE=cfr"
          "GSR_CODEC=auto"
          "GSR_AUDIO_CODEC=opus"
          "GSR_REPLAYDURATION=30"
          "GSR_OUTPUTDIR=%h/Videos"
          "GSR_MAKEFOLDERS=no"
          "GSR_COLOR_RANGE=full"
          "GSR_FPSPPS=no"
        ]
        ++ lib.optionals (nixosConfig.node.name == "kroma") [
          "GSR_WINDOW=DP-2" # Primary monitor
        ];

      ExecStart = lib.getExe start-service;
      ExecStopPost = lib.getExe on-stop-service;
      KillSignal = "SIGINT";
      Restart = "on-failure";
      RestartSec = "10";
      Type = "simple";
    };
  };
}
