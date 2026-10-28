# Single source for the Incus host and its guests. flake.nix derives both the
# NixOS configurations and the OpenTofu variables from this file. Each guest
# port is published on every host address through an Incus proxy device.
{
  host = {
    name = "incus-host";
    bridgeAddress = "10.40.0.1/24";
  };

  guests = {
    web-server = {
      enable = true;
      ipv4 = "10.40.0.10";
      cpus = 2;
      memory = "2GiB";
      diskSize = "24GiB";
      ports = [
        {
          protocol = "tcp";
          port = 80;
        }
      ];
    };

    # immich and nas stay disabled until the data HDD is mounted on the host at
    # /srv/nas-data with the immich, photos and share directories created.

    # Photo originals live in /srv/nas-data/photos, shared by Samba and read
    # by Immich as an external library. The mount points match the previous
    # Docker deployment, so database paths stay valid.
    immich = {
      enable = false;
      ipv4 = "10.40.0.11";
      cpus = 4;
      memory = "3GiB";
      diskSize = "16GiB";
      ports = [
        {
          protocol = "tcp";
          port = 2283;
        }
      ];
      disks = {
        immich-data = {
          source = "/srv/nas-data/immich";
          path = "/data";
        };
        photos = {
          source = "/srv/nas-data/photos";
          path = "/external";
          readonly = true;
        };
      };
    };

    nas = {
      enable = false;
      ipv4 = "10.40.0.12";
      cpus = 1;
      memory = "512MiB";
      diskSize = "8GiB";
      ports = [
        {
          protocol = "tcp";
          port = 445;
        }
      ];
      disks = {
        photos = {
          source = "/srv/nas-data/photos";
          path = "/srv/photos";
        };
        share = {
          source = "/srv/nas-data/share";
          path = "/srv/share";
        };
      };
    };
  };
}
