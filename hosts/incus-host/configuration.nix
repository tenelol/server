{
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot = {
    loader.grub = {
      enable = true;
      device = "/dev/vda";
    };
    growPartition = true;
  };

  fileSystems = {
    # Root disk cloned from the PVE NixOS cloud-init template.
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      autoResize = true;
    };
    # Second virtio disk used as the Incus btrfs storage pool source.
    "/var/lib/incus-storage" = {
      device = "/dev/disk/by-label/incus";
      fsType = "btrfs";
      options = [
        "compress=zstd"
        "noatime"
      ];
    };
    # The NAS data HDD; missing until it is attached to the VM.
    "/srv/nas-data" = {
      device = "/dev/disk/by-label/nas-data";
      fsType = "ext4";
      options = [
        "nofail"
        "x-systemd.device-timeout=10s"
      ];
    };
  };

  networking = {
    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network.networks."10-uplink" = {
    matchConfig.Name = "ens18";
    DHCP = "ipv4";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
