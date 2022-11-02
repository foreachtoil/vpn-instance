locals {
  secrets = {
    ssh-private-key-linux-client   = tls_private_key.ssh.private_key_openssh
    ssh-ec2-username               = "ubuntu"
  }
}