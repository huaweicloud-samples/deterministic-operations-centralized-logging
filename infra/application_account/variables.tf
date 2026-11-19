variable "region" {
  description = "华为云区域"
  type        = string
  default     = "cn-north-4"
}

variable "environment" {
  description = "环境名(prod / dev / staging)"
  type        = string
}

variable "account_name" {
  description = "应用账号名称,用于资源命名"
  type        = string
}

variable "destination_name" {
  description = "集中日志目的地名称,与日志归档账号一致"
  type        = string
}

variable "archive_obs_buckets" {
  description = "日志归档账号输出的各服务中央 OBS 桶名"
  type = object({
    rds      = string
    cce      = string
    function = string
  })
}

variable "archive_domain_name" {
  description = "日志归档账号的账号域名(跨账号委托被委托方)"
  type        = string
}

variable "agency_domain_id" {
  description = "本应用账号的账号 ID(委托方)"
  type        = string
}

variable "agency_domain_name" {
  description = "本应用账号的账号域名(委托方)"
  type        = string
}

variable "agency_project_id" {
  description = "本应用账号的项目 ID(委托方)"
  type        = string
}

variable "tags" {
  description = "通用标签"
  type        = map(string)
  default     = {}
}

variable "vpc_config" {
  description = "VPC 配置"
  type = object({
    vpc_cidr        = string
    private_subnets = list(string)
    public_subnets  = list(string)
  })
}

variable "rds_config" {
  description = "RDS 实例配置"
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
  description = "RDS 参数组配置"
  type = object({
    general_log     = number
    slow_query_log  = number
    long_query_time = number
    log_output      = string
  })
  default = {
    general_log     = 1
    slow_query_log  = 1
    long_query_time = 10
    log_output      = "FILE"
  }
}

variable "cce_config" {
  description = "CCE 集群配置"
  type = object({
    cluster_name    = string
    cluster_version = string
    flavor_id       = string
  })
}

variable "function_config" {
  description = "FunctionGraph 函数配置"
  type = object({
    name        = string
    runtime     = string
    timeout     = number
    memory_size = number
  })
  default = {
    name        = "sample-app"
    runtime     = "Python3.9"
    timeout     = 30
    memory_size = 128
  }
}

variable "ingress_allowed_cidr_blocks" {
  description = "允许访问数据库的 CIDR 列表"
  type        = list(string)
  default     = []
}

variable "egress_allowed_cidr_blocks" {
  description = "允许出站访问的 CIDR 列表"
  type        = list(string)
  default     = []
}
variable "access_key" {
  description = "华为云 Access Key(可选;不填则用环境变量)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "secret_key" {
  description = "华为云 Secret Key(可选;不填则用环境变量)"
  type        = string
  default     = ""
  sensitive   = true
}
