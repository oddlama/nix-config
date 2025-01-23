{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "mdns-repeater";
  version = "unstable-git";

  src = fetchFromGitHub {
    owner = "PatrickDaG";
    repo = "mdns-repeater";
    rev = "5178041edbd0382bdeac462223549e093b26fe12";
    hash = "sha256-cIrHSzdzFqfArE2bqWPm+CULuQU/KajkRN+i0b+seD0=";
  };

  cargoHash = "sha256-00Vh2AVECtqvkmLZmyDCR43tUqKdN4j1B8GnnRiWAmU=";

  meta = {
    description = "mDNS packet relayer";
    homepage = "https://github.com/PatrickDaG/mdns-repeater";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      oddlama
      patrickdag
    ];
    mainProgram = "mdns-repeater";
    platforms = lib.platforms.linux;
  };
}
