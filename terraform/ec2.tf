locals {
  # If NAT gateway is enabled, backend lives in private subnet (true 3-tier).
  # Otherwise backend lives in public subnet (Free Tier friendly).
  backend_subnet_id     = var.enable_nat_gateway ? aws_subnet.private[0].id : aws_subnet.public[0].id
  backend_associate_pip = !var.enable_nat_gateway

  # Default placeholder images. Replace with your DockerHub or ECR image after pushing.
  backend_image  = "node:18-alpine"  # placeholder; see README for the real flow
  frontend_image = "nginx:1.27-alpine" # placeholder; see README
}

# =====================================================================
# Backend EC2
# =====================================================================
resource "aws_instance" "backend" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = local.backend_subnet_id
  vpc_security_group_ids      = [aws_security_group.backend.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = local.backend_associate_pip

  user_data = templatefile("${path.module}/user_data_backend.sh", {
    db_host        = aws_db_instance.mysql.address
    db_port        = aws_db_instance.mysql.port
    db_name        = var.db_name
    db_user        = var.db_username
    db_password    = var.db_password
    backend_image  = local.backend_image
  })

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${local.name_prefix}-backend"
    Tier = "application"
  }

  depends_on = [aws_db_instance.mysql]
}

# =====================================================================
# Frontend EC2 (always public)
# =====================================================================
resource "aws_instance" "frontend" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.frontend.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data_frontend.sh", {
    backend_private_ip = aws_instance.backend.private_ip
    frontend_image     = local.frontend_image
  })

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${local.name_prefix}-frontend"
    Tier = "presentation"
  }

  depends_on = [aws_instance.backend]
}
