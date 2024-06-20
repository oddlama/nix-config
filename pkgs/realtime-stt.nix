{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  wheel,
  faster-whisper,
  pyaudio,
  scipy,
  torch,
  torchaudio,
  webrtcvad,
  websockets,
}:
buildPythonPackage rec {
  pname = "realtime-stt";
  version = "0.1.16";

  src = fetchFromGitHub {
    owner = "oddlama";
    repo = "RealtimeSTT";
    rev = "master";
    hash = "sha256-64RE/aT5PxuFFUTvjNefqTlAKWG1fftKV0wcY/hFlcg=";
  };

  nativeBuildInputs = [
    setuptools
    wheel
  ];

  propagatedBuildInputs = [
    faster-whisper
    pyaudio
    scipy
    torch
    torchaudio
    webrtcvad
    websockets
  ];

  postPatch = ''
    # Remove unneded modules
    substituteInPlace RealtimeSTT/audio_recorder.py \
      --replace-fail 'import pvporcupine' "" \
      --replace-fail 'import halo' ""
  '';

  preBuild = ''
    cat > setup.py << EOF
    from setuptools import setup

    setup(
      name='realtime-stt',
      packages=['RealtimeSTT'],
      version='${version}',
      install_requires=[
          "PyAudio",
          "faster-whisper",
          #"pvporcupine",
          "webrtcvad",
          "#halo",
          "torch",
          "torchaudio",
          "scipy",
          "websockets",
      ],
    )
    EOF
  '';

  pythonImportsCheck = ["RealtimeSTT"];

  meta = {
    description = "A robust, efficient, low-latency speech-to-text library with advanced voice activity detection, wake word activation and instant transcription";
    homepage = "https://github.com/KoljaB/RealtimeSTT";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [oddlama];
  };
}
