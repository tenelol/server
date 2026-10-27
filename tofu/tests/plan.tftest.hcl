# Plans against a mocked provider with the variables generated from
# inventory.nix, so `just check` catches inventory mistakes before apply.
mock_provider "incus" {}

run "inventory" {
  command = plan

  assert {
    condition     = length(incus_instance.guest) == length(var.guests)
    error_message = "Every enabled guest must become one Incus instance."
  }

  assert {
    condition = length(flatten([
      for guest in values(incus_instance.guest) : [for device in guest.device : device if device.type == "proxy"]
    ])) == length(flatten([for guest in values(var.guests) : guest.ports]))
    error_message = "Every published guest port must have a proxy device."
  }
}
