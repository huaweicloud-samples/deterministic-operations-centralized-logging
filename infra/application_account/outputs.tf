output "rds_endpoint" {
  description = "RDS 实例内网地址"
  value       = module.rds_logging.rds_endpoint
}

output "cce_cluster_id" {
  description = "CCE 集群 ID"
  value       = module.cce_logging.cluster_id
}

output "function_urn" {
  description = "示例业务函数 URN"
  value       = module.function_logging.function_urn
}