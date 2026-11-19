# ============================================================================
# 单个日志源的中央日志桶
#   KMS 加密 + 版本化 + 生命周期 + 访问日志 + 白名单写入
#   应用账号 LTS 通过跨账号委托将日志转储到此桶
# ============================================================================

# 日志桶加密密钥
resource "huaweicloud_kms_key" "logs" {
  key_alias       = "${var.environment}-${var.service_name}-logs-key"
  pending_days    = 7
  key_description = "Encryption key for ${var.service_name} central log bucket"
  is_enabled      = true
}

# 中央日志桶(KMS 加密 + 版本化 + 私有 + 生命周期 + 访问日志)
resource "huaweicloud_obs_bucket" "logs" {
  bucket        = "${var.environment}-${var.region}-${var.service_name}-logs"
  acl           = "private"
  force_destroy = true
  versioning    = true
  kms_key_id    = huaweicloud_kms_key.logs.id

  # 生命周期:30 天转低频、60 天转归档、7 年过期
  lifecycle_rule {
    name    = "logs-lifecycle"
    enabled = true

    transition {
      days          = 30
      storage_class = "WARM" # 低频访问存储
    }
    transition {
      days          = 60
      storage_class = "COLD" # 归档存储
    }
    expiration {
      days = 2555 # 约 7 年长期留存
    }
    abort_incomplete_multipart_upload {
      days = 7
    }
  }

  # 访问日志:记录谁访问了中央日志桶
  logging {
    target_bucket = var.access_logs_bucket
    target_prefix = "${var.service_name}-logs/"
  }

  tags = {
    Environment = var.environment
    Service     = var.service_name
    Purpose     = "centralized-log-archive"
  }
}

# 桶策略:仅允许白名单中的应用账号(经 LTS 委托)写入日志对象
# 每个白名单账号生成一条 Statement;OBS Principal.ID 为字符串账号 ID
resource "huaweicloud_obs_bucket_policy" "logs_write_whitelist" {
  bucket = huaweicloud_obs_bucket.logs.bucket
  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      for account in var.source_account_ids : {
        Sid    = "AllowLogWrite-${account}"
        Effect = "Allow"
        Principal = {
          ID = ["domain/${account}"]
        }
        Action = [
          "PutObject",
          "GetObject",
        ]
        Resource = [
          "${huaweicloud_obs_bucket.logs.bucket}/*",
        ]
      }
    ]
  })
}