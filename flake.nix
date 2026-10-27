{
  description = "NixOS Incus host and guests on Proxmox VE";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, sops-nix, ... }:
    let
      inherit (nixpkgs) lib;

      inventory = import ./inventory.nix;
      profile = {
        username = "tener";
        sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFkbcnmTY5/V7n2pf6Huiqdn8DPaR8qs0tHajYXQaIs";
      };

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      mkSystem =
        extraArgs: modules:
        lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inventory profile;
          }
          // extraArgs;
          modules = [ ./modules/common.nix ] ++ modules;
        };

      mkGuest =
        name: _:
        mkSystem { guestName = name; } [
          sops-nix.nixosModules.sops
          ./modules/guest.nix
          ./guests/${name}/configuration.nix
        ];

      enabledGuests = lib.filterAttrs (_: guest: guest.enable) inventory.guests;
    in
    {
      nixosConfigurations = {
        ${inventory.host.name} = mkSystem { } [
          ./modules/host.nix
          ./hosts/${inventory.host.name}/configuration.nix
        ];
      }
      // lib.mapAttrs mkGuest inventory.guests;

      lib = {
        guestNames = builtins.attrNames enabledGuests;

        # Written to tofu/inventory.auto.tfvars.json by `just tfvars`.
        tofuVars = {
          bridge_address = inventory.host.bridgeAddress;
          guests = lib.mapAttrs (_: guest: {
            inherit (guest)
              ipv4
              cpus
              memory
              ports
              ;
            disk_size = guest.diskSize;
            disks = guest.disks or { };
          }) enabledGuests;
        };
      };

      formatter = forAllSystems (pkgs: pkgs.nixfmt);

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            age
            jq
            just
            nixfmt
            opentofu
            shellcheck
            sops
          ];
        };
      });
    };
}
