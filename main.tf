resource "openstack_compute_keypair_v2" "terraform" {
  name       = "terraform"
  public_key = "${file("${var.ssh_key_file}.pub")}"
}

resource "openstack_networking_network_v2" "terraform" {
  name           = "terraform"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "terraform" {
  name            = "terraform"
  network_id      = "${openstack_networking_network_v2.terraform.id}"
  cidr            = "10.0.0.0/24"
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

resource "openstack_networking_router_v2" "terraform" {
  name             = "terraform"
  admin_state_up   = "true"
  external_network_id = "${var.external_gateway}"
}

resource "openstack_networking_router_interface_v2" "terraform" {
  router_id = "${openstack_networking_router_v2.terraform.id}"
  subnet_id = "${openstack_networking_subnet_v2.terraform.id}"
}

resource "openstack_compute_secgroup_v2" "terraform" {
  name        = "terraform"
  description = "Security group for the Terraform example instances"

  rule {
    from_port   = 20
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 2811
    to_port     = 2811
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 1025
    to_port     = 51000
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_floatingip_v2" "terraform" {
  pool       = "${var.pool}"
  depends_on = ["openstack_networking_router_interface_v2.terraform"]
}

resource "openstack_compute_instance_v2" "terraform" {
  name            = "terraform"
  image_name      = "${var.image}"
  flavor_name     = "${var.flavor}"
  key_pair        = "${openstack_compute_keypair_v2.terraform.name}"
  security_groups = ["${openstack_compute_secgroup_v2.terraform.name}"]

  network {
    uuid = "${openstack_networking_network_v2.terraform.id}"
  }

}

resource "openstack_compute_floatingip_associate_v2" "terraform" {
  floating_ip = "${openstack_compute_floatingip_v2.terraform.address}"
  instance_id = "${openstack_compute_instance_v2.terraform.id}"

  provisioner "file" {
    connection {
      host = "${openstack_compute_floatingip_v2.terraform.address}"
      user     = "${var.ssh_user_name}"
      agent = true
    }
      source      = "./centos-gridftp-rw.sh"
      destination = "/tmp/centos-gridftp-rw.sh"
    }

  provisioner "remote-exec" {
    connection {
      host = "${openstack_compute_floatingip_v2.terraform.address}"
      user     = "${var.ssh_user_name}"
      agent = true
    }

    inline = [
      "chmod +x /tmp/centos-gridftp-rw.sh",
      "/tmp/centos-gridftp-rw.sh \"${var.certificate}\" \"${var.email}\"> /tmp/centos-gridftp-rw.log"
    ]
  }

}
