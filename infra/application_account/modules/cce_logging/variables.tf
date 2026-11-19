variable "environment" {
  type = string
}

variable "account_name" {
  type = string
}

variable "region" {
  type = string
}

variable "cce_config" {
  type = object({
    cluster_name    = string
    cluster_version = string
    flavor_id       = string
  })
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "destination_name" {
  type = string
}

variable "archive_obs_bucket" {
  type = string
}

variable "agency_name" {
  type = string
}

variable "agency_domain_id" {
  type = string
}

variable "agency_domain_name" {
  type = string
}

variable "agency_project_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}