resource "incus_instance" "guest" {
  for_each = var.guests

  name     = each.key
  type     = "container"
  image    = "images:nixos/unstable"
  profiles = []

  config = {
    "boot.autostart"          = "true"
    "security.nesting"        = "true"
    "security.idmap.isolated" = "true"
    "limits.cpu"              = tostring(each.value.cpus)
    "limits.memory"           = each.value.memory
  }

  device {
    name = "root"
    type = "disk"

    properties = {
      pool = incus_storage_pool.default.name
      path = "/"
      size = each.value.disk_size
    }
  }

  device {
    name = "eth0"
    type = "nic"

    properties = {
      network                                = incus_network.incusbr0.name
      "ipv4.address"                         = each.value.ipv4
      "security.ipv4_filtering"              = "true"
      "security.acls"                        = incus_network_acl.guest[each.key].name
      "security.acls.default.ingress.action" = "reject"
      "security.acls.default.egress.action"  = "allow"
    }
  }

  # Userspace proxies keep published ports independent of the host's DHCP
  # address. Guests see these connections as coming from localhost.
  dynamic "device" {
    for_each = { for port in each.value.ports : "${port.protocol}-${port.port}" => port }

    content {
      name = "port-${device.key}"
      type = "proxy"

      properties = {
        listen  = "${device.value.protocol}:0.0.0.0:${device.value.port}"
        connect = "${device.value.protocol}:127.0.0.1:${device.value.port}"
      }
    }
  }

  # Host directories passed through with idmapped mounts, since the guest uses
  # an isolated UID range.
  dynamic "device" {
    for_each = each.value.disks

    content {
      name = device.key
      type = "disk"

      properties = {
        source   = device.value.source
        path     = device.value.path
        readonly = tostring(device.value.readonly)
        shift    = "true"
      }
    }
  }
}
