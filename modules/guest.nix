# Base for NixOS system containers created by OpenTofu from images:nixos.
# Guests have no SSH server; the host manages them through `incus exec`.
{ guestName, pkgs, ... }:
{
  boot.isContainer = true;
  # Incus guests are managed through incus exec and have no usable /dev/console.
  systemd.services.console-getty.enable = false;
  # Keep only the /sbin/init update from lxc-container.nix; the rest of that
  # module builds standalone images.
  system.build.installBootLoader = pkgs.writeShellScript "install-lxc-init" ''
    ${pkgs.coreutils}/bin/ln -fs "$1/init" /sbin/init
  '';

  networking = {
    hostName = guestName;
    # Incus does not inject a resolv.conf; DNS comes from the bridge's DHCP.
    useHostResolvConf = false;
    useNetworkd = true;
    useDHCP = false;
    firewall.enable = true;
  };

  # Incus reserves each guest's address in the bridge's DHCP server.
  systemd.network.networks."10-eth0" = {
    matchConfig.Name = "eth0";
    DHCP = "ipv4";
  };

  # Each guest receives its age identity once, through `just guest-key`.
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # Container root filesystems are btrfs subvolumes trimmed by the host.
  services.fstrim.enable = false;

  services.journald.settings.Journal.SystemMaxUse = "200M";
}
