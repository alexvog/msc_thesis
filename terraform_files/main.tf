variable "cloudinit_template_name" {
    type = string 
}

variable "proxmox_node" {
    type = string
}

variable "ssh_key" {
  type = string
  sensitive = true
}

variable "counter" {
  type = number
}

resource "proxmox_vm_qemu" "test_server" {
  count = var.counter
  name = "test-vm-${count.index + 1}"
  target_node = var.proxmox_node
  clone = var.cloudinit_template_name
  agent = 1
  os_type = "cloud-init"
  cores = 1
  sockets = 1
  cpu = "host"
  memory = 1024
  scsihw = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disk {
    slot = 0
    size = "10G"
    type = "scsi"
    storage = "local-lvm"
  }

  network {
    model = "virtio"
    bridge = "vmbr0"
  }
  
  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  ipconfig0 = "ip=192.168.122.5${count.index + 1}/24,gw=192.168.122.1"
  
  sshkeys = <<EOF
  ${var.ssh_key}
  EOF
}

# generate inventory for ansible
resource "local_file" "inventory" {
  content  = "[servers]\n${join("\n", [for instance in proxmox_vm_qemu.test_server : "${instance.name} ansible_host=${instance.default_ipv4_address}"])}"

  filename = "${pathexpand("~")}/ansible_files/inventory"
}

resource "null_resource" "remove_and_add_ssh_keys" {
  count = var.counter

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh-keygen -f "${pathexpand("~")}/.ssh/known_hosts" -R "${proxmox_vm_qemu.test_server[count.index].default_ipv4_address}" ;
      ssh-keyscan -t rsa "${proxmox_vm_qemu.test_server[count.index].default_ipv4_address}" >> "${pathexpand("~")}/.ssh/known_hosts"
    EOT
  }
}

output "IPs" {
  value = ["${proxmox_vm_qemu.test_server.*.default_ipv4_address}"]
}
