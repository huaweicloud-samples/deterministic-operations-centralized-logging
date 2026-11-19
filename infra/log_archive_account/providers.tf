provider "huaweicloud" {
  region     = var.region
  access_key = var.access_key == "" ? null : var.access_key
  secret_key = var.secret_key == "" ? null : var.secret_key

  project_id = var.project_id == "" ? null : var.project_id
  domain_id  = var.domain_id == "" ? null : var.domain_id
}
