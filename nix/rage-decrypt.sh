#!/usr/bin/env bash

set -euo pipefail

file="$1"
[[ "$file" == "/nix/store/"* ]] || { echo "Input must be a store path!"; exit 1; }
shift
identities=("$@")

# Strip .age suffix and store path prefix
basename="${file%".age"}"
basename="${basename#*"-"}"

# Calculate a unique content-based identifier (relocations of
# the source file in the nix store should not affect caching)
new_name="$(sha512sum "$file")"
new_name="${new_name:0:32}-${basename//"/"/"%"}"

# Derive the path where the decrypted file will be stored
out="/tmp/nix-import-encrypted/$new_name"
mkdir -p "$(dirname "$out")"

# Decrypt only if necessary
if [[ ! -e "$out" ]]; then
	args=()
	for i in "${identities[@]}"; do
		args+=("-i" "$i")
	done
	rage -d "${args[@]}" -o "$out" "$file"
fi

# Print decrypted content
cat "$out"
