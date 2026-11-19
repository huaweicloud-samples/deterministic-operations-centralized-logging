output "obs_bucket" {
  description = "中央日志桶名(应用账号 LTS 转储目标)"
  value       = huaweicloud_obs_bucket.logs.bucket
}

output "obs_bucket_kms_key_id" {
  description = "中央日志桶加密密钥 ID"
  value       = huaweicloud_kms_key.logs.id
}