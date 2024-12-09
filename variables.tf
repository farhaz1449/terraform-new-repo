# Output the public IP of the EC2 instance
output "web_server_public_ip" {
  value       = aws_instance.web_server.public_ip
  description = "The public IP address of the web server"
}

output "pem_file" {
  description = "PEM file content"
  value       = tls_private_key.test1.private_key_pem
  sensitive   = true
}
