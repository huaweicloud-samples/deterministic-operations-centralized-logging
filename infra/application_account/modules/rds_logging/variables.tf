variable "environment" {
  type = string
}

variable "account_name" {
  type = string
}

variable "region" {
  type = string
}

variable "rds_config" {
  type = object({
    identifier        = string
    allocated_storage = number
    engine            = string
    engine_version    = string
    instance_class    = string
    username          = string
  })
}

variable "rds_parameters" {
  type = object({
    general_log     = number
    slow_query_log  = number
    long_query_time = number
    log_output      = string
  })
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "ingress_allowed_cidr_blocks" {
  type = list(string)
}

variable "egress_allowed_cidr_blocks" {
  type = list(string)
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