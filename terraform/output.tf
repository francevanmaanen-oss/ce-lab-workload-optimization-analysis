output "instance_ids" {
  description = "Map of instance name to instance ID"
  value       = { for k, v in aws_instance.lab : k => v.id }
}

output "orphaned_volume_id" {
  description = "ID of the orphaned EBS volume"
  value       = aws_ebs_volume.orphaned.id
}

output "region" {
  description = "AWS region instances were deployed to"
  value       = var.aws_region
}