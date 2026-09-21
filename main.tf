locals {
  boot_disk_name      = var.boot_disk_name != null ? var.boot_disk_name : "${var.name_prefix}-boot-disk"
  linux_vm_name       = var.linux_vm_name != null ? var.linux_vm_name : "${var.name_prefix}-linux-vm"
  vpc_network_name    = var.vpc_network_name != null ? var.vpc_network_name : "${var.name_prefix}-private"
  ydb_serverless_name = var.ydb_serverless_name != null ? var.ydb_serverless_name : "${var.name_prefix}-ydb-serverless"
  bucket_sa_name      = var.bucket_sa_name != null ? var.bucket_sa_name : "${var.name_prefix}-bucker-sa"
  bucket_name         = var.bucket_name != null ? var.bucket_name : "${var.name_prefix}-terraform-bucket-${random_string.bucket_name.result}"
}

resource "yandex_vpc_network" "this" {
  name = local.vpc_network_name
}

resource "yandex_vpc_address" "this" {
  for_each = var.zones

  name = length(var.zones) > 1 ? "${local.linux_vm_name}-address-${substr(each.value, -1, 0)}" : "${local.linux_vm_name}-address"
  external_ipv4_address {
    zone_id = each.value
  }
}

resource "yandex_vpc_subnet" "private" {
  for_each = var.zones

  zone = each.value
  name = keys(var.subnets)[index(tolist(var.zones), each.value)]
  v4_cidr_blocks = var.subnets[each.value]
  network_id = yandex_vpc_network.this.id
}

resource "yandex_compute_disk" "secondary_disk_a" {
  count = contains(var.zones, "ru-central1-a") ? var.secondary_disks.count : 0

  name = "${var.secondary_disks.name}-a-${count.index}"
  zone = "ru-central1-a"

  type = var.secondary_disks.type
  size = var.secondary_disks.size
}

resource "yandex_compute_disk" "secondary_disk_b" {
  count = contains(var.zones, "ru-central1-b") ? var.secondary_disks.count : 0

  name = "${var.secondary_disks.name}-b-${count.index}"
  zone = "ru-central1-b"

  type = var.secondary_disks.type
  size = var.secondary_disks.size
}

resource "yandex_compute_disk" "secondary_disk_d" {
  count = contains(var.zones, "ru-central1-d") ? var.secondary_disks.count : 0

  name = "${var.secondary_disks.name}-d-${count.index}"
  zone = "ru-central1-d"

  type = var.secondary_disks.type
  size = var.secondary_disks.size
}

resource "yandex_compute_disk" "boot_disk" {
  name     = length(var.zones) > 1 ? "${local.boot_disk_name}-${substr(each.value, -1, 0)}" : local.boot_disk_name

  for_each = var.zones
  zone = each.value

  image_id = var.image_id

  type     = var.instance_resources.disk.disk_type
  size     = var.instance_resources.disk.disk_size
}

resource "yandex_compute_instance" "this" {
  
  for_each                  = var.zones
  name                      = length(var.zones) > 1 ? "${local.linux_vm_name}-${substr(each.value, -1, 0)}" : local.linux_vm_name
  allow_stopping_for_update = true
  platform_id               = var.instance_resources.platform_id
  zone                      = each.value

  resources {
    cores  = var.instance_resources.cores
    memory = var.instance_resources.memory
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot_disk[each.value].id
  }

  dynamic "secondary_disk" {
    for_each = each.value == "ru-central1-a" ? yandex_compute_disk.secondary_disk_a : each.value == "ru-central1-b" ? yandex_compute_disk.secondary_disk_b : each.value == "ru-central1-d" ? yandex_compute_disk.secondary_disk_d : []
    content {
      disk_id = try(secondary_disk.value.id, null)
    }
  }

  network_interface {
    subnet_id      = yandex_vpc_subnet.private[each.value].id
    nat            = true
    nat_ip_address = yandex_vpc_address.this[each.value].external_ipv4_address[0].address
  }

  metadata = {
    user-data = templatefile("cloud-init.yaml.tftpl", {
      ydb_connect_string = yandex_ydb_database_serverless.this.ydb_full_endpoint,
      bucket_domain_name = yandex_storage_bucket.this.bucket_domain_name
    })
  }
}

resource "yandex_ydb_database_serverless" "this" {
  name        = local.ydb_serverless_name
  location_id = "ru-central1"
}

resource "yandex_iam_service_account" "bucket" {
  name = local.bucket_sa_name
}

resource "yandex_resourcemanager_folder_iam_member" "storage_editor" {
  folder_id = var.folder_id 
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.bucket.id}"
}

resource "yandex_iam_service_account_static_access_key" "this" {
  service_account_id = yandex_iam_service_account.bucket.id
  description        = "static access key for object storage"
}

resource "yandex_storage_bucket" "this" {
  bucket     = local.bucket_name
  access_key = yandex_iam_service_account_static_access_key.this.access_key
  secret_key = yandex_iam_service_account_static_access_key.this.secret_key

  depends_on = [ yandex_resourcemanager_folder_iam_member.storage_editor]
}

resource "random_string" "bucket_name" {
  length  = 8
  special = false
  upper   = false
}

resource "yandex_mdb_mysql_cluster" "this" {
  for_each = var.zones

  network_id = yandex_vpc_network.this.id
  name = "mysql-cluster"
  environment = "PRESTABLE"
  version = "8.0"

  resources {
    resource_preset_id = "s2.micro"
    disk_type_id = "network-ssd"
    disk_size = 10
  }

  host {
    zone = each.value
    subnet_id = yandex_vpc_subnet.private[each.value].id
  }
}

resource "yandex_vpc_security_group" "this" {
  network_id = yandex_vpc_network.this.id

  dynamic "ingress" {
    for_each = var.ingress_rule
    content {
      protocol       = ingress.value.protocol
      description    = ingress.value.description
      v4_cidr_blocks = ingress.value.v4_cidr_blocks
      port           = ingress.value.port
    }
  }
}

resource "yandex_mdb_mysql_database" "database" {
  for_each = length(var.databases) > 0 ? {for db in var.databases : db.name => db} : {}

  cluster_id = yandex_mdb_mysql_cluster.this[each.value].id
  name              = lookup(each.value, "name", null)
}


resource "yandex_mdb_mysql_user" "user" {
  for_each = length(var.users) > 0 ? { for u in var.users : u.name => u } : {}
  
  cluster_id = yandex_mdb_mysql_cluster.this[each.value].id
  name       = each.value.name
  password   = each.value.password
  dynamic "permission" {
    for_each = lookup(each.value, "permissions", [])
    content {
      database_name = permission.value.database_name
      roles = permission.value.roles
    }
  }

  depends_on = [ yandex_mdb_mysql_database.database ]
}