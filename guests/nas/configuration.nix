# File shares for the Mac and iPhone over SMB. Samba needs a password set once
# with `incus exec nas -- smbpasswd -a <user>`; it is not kept in this repo.
{ inventory, profile, ... }:
let
  inherit (inventory.guests.nas) disks;
  mkShare = path: {
    inherit path;
    "read only" = "no";
    "valid users" = profile.username;
    "create mask" = "0644";
    "directory mask" = "0755";
  };
in
{
  services.samba = {
    enable = true;
    openFirewall = true;
    # Clients connect to the host by name or address; NetBIOS discovery does
    # not cross the Incus NAT.
    nmbd.enable = false;
    winbindd.enable = false;
    settings = {
      global = {
        "server min protocol" = "SMB3";
        "map to guest" = "never";
        # Keep macOS metadata and resource forks in extended attributes.
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:metadata" = "stream";
        "fruit:encoding" = "native";
      };
      photos = mkShare disks.photos.path;
      share = mkShare disks.share.path;
    };
  };
}
