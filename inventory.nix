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

    # Created only after the data HDD is attached to the host and mounted at
    # /srv/nas-data. DLNA discovery (SSDP multicast) does not reach the guest.
    nas = {
      enable = false;
      ipv4 = "10.40.0.12";
      cpus = 2;
      memory = "2GiB";
      diskSize = "16GiB";
      ports = [
        {
          protocol = "tcp";
          port = 5001;
        }
        {
          protocol = "tcp";
          port = 8080;
        }
        {
          protocol = "tcp";
          port = 8081;
        }
        {
          protocol = "tcp";
          port = 9001;
        }
        {
          protocol = "tcp";
          port = 9002;
        }
      ];
      disks.nas-data = {
        source = "/srv/nas-data";
        path = "/srv/nas-data";
      };
    };
  };
}
