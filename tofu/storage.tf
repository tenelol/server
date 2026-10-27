resource "incus_storage_pool" "default" {
  name   = "default"
  driver = "btrfs"

  config = {
    source = "/var/lib/incus-storage"
  }

  description = "Guest root filesystems on the dedicated btrfs disk"
}
