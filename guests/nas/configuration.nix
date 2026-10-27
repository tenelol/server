# Not deployed until the data HDD exists; see inventory.nix.
{
  inventory,
  pkgs,
  ...
}:
let
  # Mounted on the host and passed in as an Incus disk device.
  dataMount = inventory.guests.nas.disks.nas-data.path;
  ums = pkgs.callPackage ../../packages/universal-media-server.nix { };
  storageServices = [
    "filebrowser"
    "nextcloud-cron"
    "nextcloud-setup"
    "ums"
  ];
in
{
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud35;
    hostName = "nas";
    datadir = "${dataMount}/nextcloud-data";
    configureRedis = true;
    database.createLocally = true;
    # nixpkgs no longer creates the admin account; create it once with
    # nextcloud-occ user:add and group:adduser admin.
    config.dbtype = "mysql";
    maxUploadSize = "16G";
    settings.trusted_domains = [
      "nas"
      "localhost"
      inventory.host.name
    ];
  };

  services.nginx.virtualHosts.nas.listen = [
    {
      addr = "0.0.0.0";
      port = 8081;
    }
    {
      addr = "[::]";
      port = 8081;
    }
  ];

  services.filebrowser = {
    enable = true;
    openFirewall = true;
    settings = {
      address = "0.0.0.0";
      port = 8080;
      root = dataMount;
      database = "/var/lib/filebrowser/database.db";
      enableThumbnails = true;
    };
  };

  users.groups.nas-media = { };
  users.users.ums = {
    isSystemUser = true;
    group = "nas-media";
    home = "/var/lib/ums";
  };

  systemd.services = {
    ums = {
      description = "Universal Media Server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = {
        HOME = "/var/lib/ums";
        UMS_MAX_MEMORY = "800M";
      };
      serviceConfig = {
        User = "ums";
        Group = "nas-media";
        ExecStart = "${ums}/bin/ums";
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = "ums";
        WorkingDirectory = "/var/lib/ums";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [
          dataMount
          "/var/lib/ums"
        ];
      };
    };
  }
  // builtins.listToAttrs (
    map (name: {
      inherit name;
      value.unitConfig.RequiresMountsFor = dataMount;
    }) storageServices
  );

  networking.firewall = {
    allowedTCPPorts = [
      5001
      8081
      9001
      9002
    ];
  };
}
