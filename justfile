set positional-arguments

host := "incus-host"

# List recipes
default:
    @just --list

# Validate Nix, OpenTofu and shell scripts without building
check:
    nix flake check --no-build
    nix eval --json .#nixosConfigurations --apply 'builtins.mapAttrs (_: c: c.config.system.build.toplevel.drvPath)' >/dev/null
    git ls-files -z '*.nix' | xargs -0 nixfmt --check
    nix eval --json .#lib.tofuVars > tofu/inventory.auto.tfvars.json
    tofu -chdir=tofu fmt -check -recursive
    tofu -chdir=tofu init -backend=false -lockfile=readonly >/dev/null
    tofu -chdir=tofu validate
    tofu -chdir=tofu test
    shellcheck scripts/*.sh

# Write OpenTofu variables generated from inventory.nix
tfvars:
    nix eval --json .#lib.tofuVars > tofu/inventory.auto.tfvars.json

# Show Incus changes (run on the host)
plan: tfvars
    tofu -chdir=tofu init -lockfile=readonly >/dev/null
    tofu -chdir=tofu plan

# Apply Incus networks, storage and instances (run on the host)
apply: tfvars
    tofu -chdir=tofu init -lockfile=readonly >/dev/null
    tofu -chdir=tofu apply

# Build and activate guests; all enabled guests when none are given (run on the host)
deploy *guests:
    ./scripts/deploy-guests.sh "$@"

# Switch the host to this checkout (run on the host)
switch-host:
    sudo nixos-rebuild switch --flake .#{{ host }}

# Install a guest's sops age identity read from stdin (run on the host)
guest-key guest:
    incus exec -T "$1" -- sh -c 'umask 077 && mkdir -p /var/lib/sops-nix && cat > /var/lib/sops-nix/key.txt'
