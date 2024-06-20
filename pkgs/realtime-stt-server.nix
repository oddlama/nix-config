{
  lib,
  python3,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "realtime-stt-server";
  version = "1.0.0";

  dontUnpack = true;
  propagatedBuildInputs = [
    (python3.withPackages (pythonPackages: with pythonPackages; [realtime-stt]))
  ];

  installPhase = ''
    install -Dm755 ${./realtime-stt-server.py} $out/bin/realtime-stt-server
  '';

  meta = {
    description = "";
    homepage = "";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [oddlama];
    mainProgram = "realtime-stt-server";
  };
}
