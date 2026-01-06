resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = var.ssh_key_name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/${var.ssh_key_name}.pem"
  file_permission = "0400"
}

resource "aws_instance" "minikube" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.main.key_name
  vpc_security_group_ids      = [aws_security_group.minikube.id]
  subnet_id                   = aws_subnet.public.id
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    ecr_repository = var.ecr_repository
    project_name   = var.project_name
  }))

  tags = { Name = "${var.project_name}-minikube" }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

resource "aws_eip" "main" {
  instance = aws_instance.minikube.id
  domain   = "vpc"
  tags     = { Name = "${var.project_name}-eip" }
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "/greenroad/app"
  retention_in_days = 7
}
