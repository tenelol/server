# Values come from inventory.nix through inventory.auto.tfvars.json.

variable "bridge_address" {
  type        = string
  description = "Address and prefix of the managed guest bridge."

  validation {
    condition     = can(cidrhost(var.bridge_address, 0))
    error_message = "bridge_address must be an address with a prefix length."
  }
}

variable "guests" {
  type = map(object({
    ipv4      = string
    cpus      = number
    memory    = string
    disk_size = string
    ports = list(object({
      protocol = string
      port     = number
    }))
    disks = map(object({
      source = string
      path   = string
    }))
  }))

  validation {
    condition = alltrue([
      for name in keys(var.guests) :
      can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", name)) && length(name) <= 63
    ])
    error_message = "Guest names must be lowercase DNS labels of at most 63 characters."
  }

  validation {
    condition = alltrue([
      for guest in values(var.guests) :
      cidrcontains(var.bridge_address, guest.ipv4) && guest.ipv4 != split("/", var.bridge_address)[0]
    ])
    error_message = "Each guest ipv4 must be inside bridge_address and differ from the bridge address."
  }

  validation {
    condition     = length(distinct([for guest in values(var.guests) : guest.ipv4])) == length(var.guests)
    error_message = "Guest addresses must be unique."
  }

  validation {
    condition = alltrue(flatten([
      for guest in values(var.guests) : [
        for port in guest.ports : contains(["tcp", "udp"], port.protocol) && port.port >= 1 && port.port <= 65535
      ]
    ]))
    error_message = "Ports must use tcp or udp and a port number between 1 and 65535."
  }

  validation {
    condition = length(flatten([
      for guest in values(var.guests) : [for port in guest.ports : "${port.protocol}/${port.port}"]
      ])) == length(distinct(flatten([
        for guest in values(var.guests) : [for port in guest.ports : "${port.protocol}/${port.port}"]
    ])))
    error_message = "A published protocol and port pair can belong to only one guest."
  }
}
