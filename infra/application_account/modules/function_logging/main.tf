# ============================================================================
# FunctionGraph 日志源
#   示例业务函数 + 启用 LTS 日志 → 汇聚 LTS 组 → 跨账号转储到归档 OBS
# ============================================================================

locals {
  log_group_name = "${var.destination_name}-function"
}

# FunctionGraph 函数(示例业务函数,对应集中观测的应用函数日志)
# 示例函数仅输出运行日志,不访问其他云服务,无需执行委托
resource "huaweicloud_fgs_function" "sample" {
  name        = "${var.environment}-${var.function_config.name}"
  app         = "default"
  handler     = "index.handler"
  memory_size = var.function_config.memory_size
  timeout     = var.function_config.timeout
  runtime     = var.function_config.runtime
  code_type   = "inline"
  func_code   = base64encode(file("${path.module}/../../functions/sample_app/index.py"))

  tags = var.tags
}

# 启用 FunctionGraph 的 LTS 日志功能(账号级一次动作)
resource "huaweicloud_fgs_lts_log_enable" "this" {}

# 汇聚 LTS 日志组/流:函数日志关联到本组后统一转储归档
resource "huaweicloud_lts_group" "function" {
  group_name  = local.log_group_name
  ttl_in_days = 365
}

resource "huaweicloud_lts_stream" "function" {
  group_id    = huaweicloud_lts_group.function.id
  stream_name = "${local.log_group_name}-stream"
}

# LTS 跨账号转储:经委托把函数日志写入归档账号中央 OBS
resource "huaweicloud_lts_transfer" "to_archive" {
  log_group_id = huaweicloud_lts_group.function.id

  log_streams {
    log_stream_id = huaweicloud_lts_stream.function.id
  }

  log_transfer_info {
    log_transfer_type   = "OBS"
    log_transfer_mode   = "cycle"
    log_storage_format  = "RAW"
    log_transfer_status = "ENABLE"

    log_transfer_detail {
      obs_period           = 1
      obs_period_unit      = "hour"
      obs_bucket_name      = var.archive_obs_bucket
      obs_dir_prefix_name  = "function/"
      obs_encrypted_enable = true
    }

    log_agency_transfer {
      agency_domain_id   = var.agency_domain_id
      agency_domain_name = var.agency_domain_name
      agency_name        = var.agency_name
      agency_project_id  = var.agency_project_id
    }
  }
}

output "function_urn" {
  value = huaweicloud_fgs_function.sample.urn
}

output "log_group_id" {
  value = huaweicloud_lts_group.function.id
}