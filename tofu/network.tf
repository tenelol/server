resource "incus_network" "incusbr0" {
  name = "incusbr0"
  type = "bridge"

  description = "Managed bridge for guests"

  config = {
    "ipv4.address"  = var.bridge_address
    "ipv4.nat"      = "true"
    "ipv4.dhcp"     = "true"
    "ipv4.firewall" = "true"
    "ipv6.address"  = "none"
  }
}

resource "incus_network_acl" "guest" {
  for_each = var.guests

  name = each.key

  # The provider reads an empty rule set back as null.
  ingress = length(each.value.ports) > 0 ? [
    for port in each.value.ports : {
      action           = "allow"
      protocol         = port.protocol
      destination_port = tostring(port.port)
      state            = "enabled"
    }
  ] : null
}
