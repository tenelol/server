# Migrated from the Docker deployment on PVE VM 103 (Immich v3.2.4).
{ inventory, ... }:
let
  inherit (inventory.guests.immich) disks;
  # Fixed so the HDD directory can be owned by this user on the host.
  uid = 2283;
in
{
  services.immich = {
    enable = true;
    mediaLocation = disks.immich-data.path;
    # Face and object recognition were disabled in the previous deployment.
    machine-learning.enable = false;
    settings = {
      machineLearning.enabled = false;
      ffmpeg = {
        targetResolution = "1080";
        targetVideoCodec = "h264";
        maxBitrate = "6M";
        crf = 23;
        preset = "veryfast";
        threads = 2;
        transcode = "all";
      };
      job = {
        thumbnailGeneration.concurrency = 4;
        metadataExtraction.concurrency = 2;
        videoConversion.concurrency = 1;
      };
    };
  };

  users.users.immich.uid = uid;
  users.groups.immich.gid = uid;
}
