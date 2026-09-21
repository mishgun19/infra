variable "name_prefix" {
  description = "Optional - Name prefix for project"
  type        = string
  default     = "project"
}

variable "cloud_id" {
  description = "Optional - Yandex Cloud ID where resources will be created."
  type        = string
}

variable "key_file" {
  description = "Optional - Key file in JSON format for Cloud."
  type        = string
}

variable "folder_id" {
  description = "Optional - Yandex Folder Cloud ID where resources will be created."
  type        = string
}

variable "zones" {
  description = "Optional - Yandex Cloud Zone for provisoned resources."
  type        = set(string)
  default     = ["ru-central1-a", "ru-central1-b", "ru-central1-d"]
}

variable "image_id" {
  description = "Optional - Boot disk image id. If not provided, it defaults to Ubuntu 22.04 LTS image id."
  type        = string
  default     = "fd8ba9d5mfvlncknt2kd"
}

variable "instance_resources" {
  description = <<EOF
    Optional - Specifies the resources allocated to an instance.
      - `platform_id`: The type of virtual machine to create. If not provided, it defaults to `standard-v3`.
      - `cores`: The number of CPU cores allocated to the instance.
      - `memory`: The amount memory (in GiB) allocated to the instance.
      - `disk`: Configuration for the instance disk.
        - `disk_type`: The type of disk for the instance.If not provided, it defaults to `network-ssd`.
        - `disk_size`: The size of the disk(in GiB) allocated to the instance. If not provided, it defaults to 15 GiB.
  EOF

  type = object ({
    platform_id = optional(string, "standard-v3")
    cores       = number
    memory      = number
    disk        = optional(object({
      disk_type = optional(string,"network-ssd")
      disk_size = optional(number,15)
    }), {})
  })
}

variable "subnets" {
  description       = "Optional - A map of subnet names to their CIDR block ranges."
  type              = map(list(string))
  default           = {
    "ru-central1-a" = ["192.168.10.0/24"],
    "ru-central1-b" = ["192.168.11.0/24"],
    "ru-central1-d" = ["192.168.12.0/24"]
  }
}

variable "server_counts" {
  default = {
    "App-sever" = 2,
    "Db-server" = 2,
    "Storage"   = 1,
    "Balancer"  = 1
  }
}

variable "server" {
  default = {
    "App-server" = "app",
    "Db-server"  = "db",
    "Storage"    = "storage",
    "Balancer"   = "balancer"
  }
}

variable "linux_vm_name" {
  description = "Name -f the Linux VM"
  type = string
  default = null
}

variable "instance" {
  type        = map(object({
    zone      = string
    resources = object({
      cores   = number
      memory  = number 
    })
  }))

  default = {
    "server-1"  = {
      zone      = "ru-central1-a"
      resources = {
        cores   = 2
        memory  = 2
      }
    }
    "server-2" = {
      zone      = "ru-central1-a"
      resources = {
        cores   = 4
        memory  = 4
      }
    }
  }
}

variable "secondary_disks" {
  description = "Configurate for secondary disks"
  type = object({
    count = number
    name  = string
    type  = string
    size  = number
  })
  default = {
    count = 2
    name = "secondary-disk"
    type = "network-hdd"
    size = 10
  }
}

variable "vpc_network_name" {
  description = "Name -f the VPC network"
  type = string
  default = null
}

variable "ydb_serverless_name" {
  description = "Name of the YDB serverless"
  type = string
  default = null
}

variable "bucket_sa_name" {
  description = "Name of the service account for the bucket"
  type = string
  default = null
}

variable "bucket_name" {
  description = "Name of the bucket"
  type = string
  default = null
}

variable "boot_disk_name" {
  description = "Name of the boot disk"
  type = string
  default = null
}

variable "ingress_rule" {
  type             = list(object({
    protocol       = string
    description    = string
    v4_cidr_blocks = list(string)
    port           = number
  }))
  default = [ {
    protocol       = "TCP"
    description    = "HTTP"  
    v4_cidr_blocks = [ "10.0.1.0/24" ]
    port           = 80
  },
  {
    protocol       = "TCP"
    description    = "HTTPS"
    v4_cidr_blocks = [ "0.0.0.0/24" ]
    port           = 443
  }
   ] 
}

variable "databases" {
  type   = list(object({
    name = string
  }))
}

variable "users" {
  type                    = list(object({
    name                  = string
    password              = optional(string,null)
    authentication_plugin = optional(string,null)
    global_permissions    = optional(list(string), [])
    connection_limits     = optional(object({
      max_questions_per_hour   = optional(number, -1)
      max_updates_per_hour     = optional(number, -1)
      max_connections_per_hour = optional(number, -1)
      max_user_connections     = optional(number, -1)
    }), null)
    permissions = optional(list(object({
      database_name = string
      roles         = optional(list(string), ["ALL"])
    })), [])
  }))
}

