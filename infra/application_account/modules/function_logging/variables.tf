variable "environment" {
  type = string
}

variable "account_name" {
  type = string
}

variable "region" {
  type = string
}

variable "function_config" {
  type = object({
    name        = string
    runtime     = string
    timeout     = number
    memory_size = number
  })
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