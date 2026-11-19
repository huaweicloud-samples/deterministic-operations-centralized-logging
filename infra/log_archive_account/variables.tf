variable "region" {
  description = "华为云区域"
  type        = string
  default     = "cn-north-4"
}

variable "environment" {
  description = "环境名(prod / dev / staging)"
  type        = string
}

variable "destination_name" {
  description = "集中日志目的地名称,应用账号侧用同一名称创建跨账号汇聚"
  type        = string
}

variable "source_account_ids" {
  description = "允许汇聚日志的应用账号 ID 列表(跨账号白名单,对应 IAM 委托方)"
  type        = list(string)
  default     = []
}

variable "agency_domain_name" {
  description = "华为云账号域名(委托归属域)"
  type        = string
}

variable "log_retention_days" {
  description = "归档账号 LTS 日志组留存天数"
  type        = number
  default     = 365
}

variable "obs_transfer_period" {
  description = "LTS 转储 OBS 的周期: 2/5/30(min) 或 1/3/6/12(hour)"
  type        = number
  default     = 1
}

variable "obs_transfer_period_unit" {
  description = "转储周期单位: min / hour"
  type        = string
  default     = "hour"
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

variable "project_id" {
  description = "华为云项目 ID(可选,默认按 region 解析)"
  type        = string
  default     = ""
}

variable "domain_id" {
  description = "华为云账号 ID(可选)"
  type        = string
  default     = ""
}
