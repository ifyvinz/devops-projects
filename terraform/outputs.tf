# --- Outputs ---

output "bastion_public_ip" {
  description = "Public IP address of the Bastion Host"
  value       = aws_instance.bastion.public_ip
}

output "k3s_master_private_ip" {
  description = "Private IP address of the K3s Master Node"
  value       = aws_instance.k3s_master.private_ip
}

output "k3s_worker_private_ip" {
  description = "Private IP address of the K3s Worker Node"
  value       = aws_instance.k3s_worker.private_ip
}

output "private_key_filepath" {
  description = "Path to the generated SSH private key file. Use this to SSH into the bastion host."
  value       = local_file.private_key_pem.filename
}