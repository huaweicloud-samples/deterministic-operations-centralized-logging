output "central_buckets" {
  description = "各服务中央日志桶名"
  value = {
    rds      = module.log_destination_rds.obs_bucket
    cce      = module.log_destination_cce.obs_bucket
    function = module.log_destination_function.obs_bucket
  }
}

output "log_processor_function_urn" {
  description = "日志处理函数 URN"
  value       = huaweicloud_fgs_function.log_processor.urn
}