output "alb_dns_name" {
  description = "Public DNS of the ALB — open this in your browser"
  value       = aws_lb.app.dns_name
}

output "frontend_public_ip" {
  description = "Frontend EC2 public IP (for SSH and direct test)"
  value       = aws_instance.frontend.public_ip
}

output "backend_public_ip" {
  description = "Backend EC2 public IP (null if NAT enabled and backend is private)"
  value       = aws_instance.backend.public_ip
}

output "backend_private_ip" {
  description = "Backend EC2 private IP — used by NGINX on the frontend host"
  value       = aws_instance.backend.private_ip
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint (use as DB_HOST in the backend)"
  value       = aws_db_instance.mysql.address
}

output "rds_port" {
  description = "RDS MySQL port"
  value       = aws_db_instance.mysql.port
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "ssh_frontend_command" {
  description = "Ready-to-use SSH command for frontend EC2"
  value       = "ssh -i ${var.key_pair_name}.pem ubuntu@${aws_instance.frontend.public_ip}"
}

output "ssh_backend_command" {
  description = "SSH command for backend (works only when backend is in public subnet)"
  value       = aws_instance.backend.public_ip != "" ? "ssh -i ${var.key_pair_name}.pem ubuntu@${aws_instance.backend.public_ip}" : "Backend is in private subnet - SSH via frontend as bastion"
}
