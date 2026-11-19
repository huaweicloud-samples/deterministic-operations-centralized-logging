variable "service_name" {
  description = "日志来源服务名(rds / cce / function)"
  type        = string
}

variable "environment" {
  description = "环境名"
  type        = string
}

variable "region" {
  description = "区域"
  type        = string
}

variable "access_logs_bucket" {
  description = "共享访问日志桶名"
  type        = string
}

variable "source_account_ids" {
  description = "允许写入日志的应用账号 ID 列表(桶策略白名单)"
  type        = list(string)
  default     = []
}

variable "log_processor_function_urn" {
  description = "日志处理 FunctionGraph 函数 URN,接收 OBS 事件通知"
  type        = string
}