inputs: final: prev: let
  inherit
    (prev.lib)
    concatMapStrings
    escapeShellArg
    ;

  inherit
    (final.lib)
    isAbsolutePath
    ;
in {
  lib =
    prev.lib
    // {
      secrets = let
        rageMasterIdentityArgs = concatMapStrings (x: "-i ${escapeShellArg x} ") inputs.self.secretsConfig.masterIdentities;
        rageExtraEncryptionPubkeys =
          concatMapStrings (
            x:
              if isAbsolutePath x
              then "-R ${escapeShellArg x} "
              else "-r ${escapeShellArg x} "
          )
          inputs.self.secretsConfig.extraEncryptionPubkeys;
      in {
        # TODO replace these by lib.agenix-rekey
        # The arguments required to de-/encrypt a secret in this repository
        rageDecryptArgs = "${rageMasterIdentityArgs}";
        rageEncryptArgs = "${rageMasterIdentityArgs} ${rageExtraEncryptionPubkeys}";
      };
    };
}
