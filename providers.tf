terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    random = {
      source = "hashicorp/random"
    }
  }
  required_version = ">= 1.00"
}

provider "yandex" {
  zone                     = "ru-central1-a"
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  service_account_key_file = var.key_file
}

provider "random" {

}
