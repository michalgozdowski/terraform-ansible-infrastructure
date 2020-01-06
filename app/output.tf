output "ssh_password" {
  value       = aws_key_pair.keypair.key_name
  description = "SSH public key"
  sensitive   = true
}
