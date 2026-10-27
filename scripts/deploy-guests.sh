#!/usr/bin/env bash
# Build guest systems on the Incus host, copy only the store paths each guest
# lacks, and activate them. Guests need neither SSH nor flake evaluation.
set -euo pipefail

fail() {
  echo "deploy-guests: $*" >&2
  exit 1
}

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

if (($# > 0)); then
  guests=("$@")
else
  mapfile -t guests < <(nix eval --json "$repo_root#lib.guestNames" | jq -r '.[]')
fi
((${#guests[@]} > 0)) || fail "no guests to deploy"

declare -A outputs
for guest in "${guests[@]}"; do
  [[ $guest =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || fail "invalid guest name: $guest"
  incus info "$guest" >/dev/null || fail "guest not found: $guest (run just apply first)"
  echo "$guest: building"
  outputs[$guest]=$(nix build --no-link --print-out-paths \
    "$repo_root#nixosConfigurations.$guest.config.system.build.toplevel")
done

for guest in "${guests[@]}"; do
  out=${outputs[$guest]}

  # The guest may still be booting right after creation.
  for _ in {1..30}; do
    incus exec "$guest" -- true >/dev/null 2>&1 && break
    sleep 2
  done

  mapfile -t missing < <(
    nix-store --query --requisites "$out" |
      incus exec -T "$guest" -- xargs -r nix-store --check-validity --print-invalid
  )
  if ((${#missing[@]} > 0)); then
    echo "$guest: copying ${#missing[@]} store paths"
    nix-store --export "${missing[@]}" | incus exec -T "$guest" -- nix-store --import >/dev/null
  fi

  echo "$guest: activating $out"
  incus exec "$guest" -- nix-env --profile /nix/var/nix/profiles/system --set "$out"
  incus exec "$guest" -- "$out/bin/switch-to-configuration" switch
done
