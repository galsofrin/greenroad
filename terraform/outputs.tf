output "ec2_public_ip" {
  value = aws_eip.main.public_ip
}

output "ssh_command" {
  value = "ssh -i ${var.ssh_key_name}.pem ubuntu@${aws_eip.main.public_ip}"
}

output "app_url" {
  value = "http://${aws_eip.main.public_ip}:3000"
}

output "grafana_url" {
  value = "http://${aws_eip.main.public_ip}:3001 (admin/admin123)"
}

output "prometheus_url" {
  value = "http://${aws_eip.main.public_ip}:9090"
}

output "instance_type" {
  value = var.instance_type
}

# GitHub Actions Credentials
output "github_actions_access_key_id" {
  description = "AWS Access Key ID for GitHub Actions"
  value       = aws_iam_access_key.github_actions.id
  sensitive   = true
}

output "github_actions_secret_access_key" {
  description = "AWS Secret Access Key for GitHub Actions"
  value       = aws_iam_access_key.github_actions.secret
  sensitive   = true
}

output "github_secrets_setup" {
  value = <<-EOT
    
    ============================================
    GitHub Actions Secrets Setup
    ============================================
    
    Go to: https://github.com/galsofrin/greenroad/settings/secrets/actions
    
    Add these 4 secrets:
    
    1. AWS_ACCESS_KEY_ID
       Run: terraform output -raw github_actions_access_key_id
    
    2. AWS_SECRET_ACCESS_KEY
       Run: terraform output -raw github_actions_secret_access_key
    
    3. EC2_HOST
       Value: ${aws_eip.main.public_ip}
    
    4. EC2_SSH_KEY
       Run: cat ${var.ssh_key_name}.pem
       (Copy entire contents including BEGIN/END lines)
    
    ============================================
  EOT
}
