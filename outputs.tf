output "boot_disk_ids" {
  description = "The ID of the boot disk created for the instance."
  value       = {
    for disk in yandex_compute_disk.boot_disk :
    disk.name => disk.id
  }
}

output "instance_ids" {
 description = "The ID of the Yandex Compute instance."
  value      = {
    for instance in yandex_compute_instance.this :
    instance.name => instance.id
  }
}

output "subnet_ids" {
  description = "The ID of the VPC subnet used by the Yandex Compute instance."
  value       = {
    for cidr_blok,subnet_info in module.net.public_subnets :
    subnet_info.name => subnet_info.subnet_id
  }
}

output "instance_public_ip_addresses" {
  description = "The IP addresses of the instances"
  value = {
    for address in yandex_vpc_address.this :
    address.name => address.external_ipv4_address[0].address
  }
}

output "ydb_id" {
  description = "The ID of the Yandex Managed Service for YDB instance."
  value       = yandex_ydb_database_serverless.this.id
}

output "service_account_id" {
  description = "The ID of the Yandex IAM service account."
  value       = module.s3.storage_admin_service_account_id
}

output "bucket_name" {
  description = "The name of the Yandex Object Storage bucket."
  value       = module.s3.bucket_name
}

output "service_account_static_access_key" {
  description = "The path to Account Service Access Key file for Yandex Cloud."
  value       = var.key_file 
  sensitive   = true
}


output "prefix" {
  value = var.name_prefix == "project-dev" ? "True" : "False"
}

output "name" {
  value = [for k in yandex_compute_instance.this:
    "${k.name} is vm of klaster."
  ]
}

output "server" {
  value = [for k, v in var.server:
  "${k} has ${v}"
  ]
}

output "in" {
  value = var.instance_resources
}

output "serial_port_files" {
  description = "The serial port's outpit files."
  value = [
    for instance in yandex_compute_instance.this :
    "serial_output_${instance.name}.txt"
  ]
}

