resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "aws_instance" "vpn" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3a.large"
  subnet_id = aws_subnet.public_subnets[0].id
  iam_instance_profile = aws_iam_instance_profile.parameter_store_profile.name
  tags = {
    Name = "VPN Instance"
  }
  root_block_device {
    encrypted   = true
    volume_size = "40"
    volume_type = "gp3"
  }
  key_name  = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.vpn.id]
}

resource "aws_eip" "public_ips" {
  instance = aws_instance.vpn.id
  vpc      = true
}

resource "aws_key_pair" "generated_key" {
  key_name   = "vpn_instance_server"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "aws_ssm_parameter" "secret" {
  for_each = local.secrets
  name     = "/${each.key}"
  type     = "SecureString"
  value    = each.value
}

resource "aws_security_group" "vpn" {
  name        = "vpn-sg"
  vpc_id      = module.vpc.vpc_id
  description = "Control traffic to/from VPN Server"

  tags = { Name = "vpn-sg" }
}

resource "aws_security_group_rule" "vpn_egress_default" {
  security_group_id = aws_security_group.vpn.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "vpn_ingress_from_public_ip" {
  security_group_id = aws_security_group.vpn.id
  type              = "ingress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["${chomp(data.http.public_ip.body)}/32"]
}

resource "aws_iam_role" "ec2_parameter_store_access_role" {
  name               = "parameter-store-role"
  assume_role_policy = file("./policies/assume_role.json")
}

resource "aws_iam_instance_profile" "parameter_store_profile" {
  name  = "parameter-store-profile"
  role = aws_iam_role.ec2_parameter_store_access_role.name
}

resource "aws_iam_policy" "policy" {
  name        = "parameter-store-policy"
  description = "Policty to access Parameter Store"
  policy      = file("./policies/policy_parameter_store.json")
}

resource "aws_iam_policy_attachment" "parameter_store" {
  name       = "parameter-store-attachment"
  roles      = [aws_iam_role.ec2_parameter_store_access_role.name]
  policy_arn = aws_iam_policy.policy.arn
}
