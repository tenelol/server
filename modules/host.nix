# Incus host running as a Proxmox VE VM. OpenTofu owns the Incus networks,
# storage and instances; this module only provides the daemon and access.
{
  inventory,
  lib,
  pkgs,
  profile,
  ...
}:
let
  enabledGuests = lib.filterAttrs (_: guest: guest.enable) inventory.guests;
  publishedPorts =
    protocol:
    lib.concatMap (
      guest: map (port: port.port) (lib.filter (port: port.protocol == protocol) guest.ports)
    ) (lib.attrValues enabledGuests);
in
{
  networking = {
    hostName = inventory.host.name;
    # Incus on NixOS requires nftables.
    nftables.enable = true;
    firewall = {
      enable = true;
      # Incus proxy devices listen on the host for each published guest port.
      allowedTCPPorts = publishedPorts "tcp";
      allowedUDPPorts = publishedPorts "udp";
      # Guests use the bridge's dnsmasq for DHCP and DNS.
      interfaces.incusbr0 = {
        allowedTCPPorts = [ 53 ];
        allowedUDPPorts = [
          53
          67
        ];
      };
    };
  };

  virtualisation.incus.enable = true;

  services = {
    qemuGuest.enable = true;
    tailscale.enable = true;
    openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        AllowUsers = [ profile.username ];
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };

  users.users.${profile.username} = {
    extraGroups = [ "incus-admin" ];
    openssh.authorizedKeys.keys = [ profile.sshPublicKey ];
  };

  security.sudo.extraRules = [
    {
      users = [ profile.username ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # No disk swap is configured; zram keeps builds from exhausting memory.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  environment.systemPackages = with pkgs; [
    jq
    just
    opentofu
  ];

  services.cloud-init.enable = lib.mkForce false;
}
