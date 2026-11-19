# ============================================================================
# 日志归档账号(Log Archive Account)
#   共享访问日志桶 + FunctionGraph 日志处理函数
#   每个日志源(rds/cce/function)一套 log_destination 模块:
#     中央 OBS 桶(加密/版本化/生命周期/访问日志/白名单写入)
#   应用账号 LTS 通过跨账号委托将日志转储到各中央桶
# ============================================================================

resource "random_id" "suffix" {
  byte_length = 4
}

# 共享访问日志桶(记录所有中央日志桶的访问日志)
resource "huaweicloud_obs_bucket" "access_logs" {
  bucket        = "${var.environment}-${var.region}-obs-access-logs-${random_id.suffix.hex}"
  acl           = "log-delivery-write" # 允许日志投递组写入访问日志
  force_destroy = true
  versioning    = true
}

# FunctionGraph 日志处理函数(新日志落盘触发)
resource "huaweicloud_fgs_function" "log_processor" {
  name        = "${var.environment}-log-processor"
  app         = "default"
  handler     = "index.handler"
  memory_size = 128
  timeout     = 60
  runtime     = "Python3.9"
  code_type   = "inline"
  func_code   = base64encode(file("${path.module}/functions/log_processor/index.py"))

  user_data = jsonencode({
    LOG_BUCKETS = join(",", [
      module.log_destination_rds.obs_bucket,
      module.log_destination_cce.obs_bucket,
      module.log_destination_function.obs_bucket,
    ])
    REGION = var.region
  })
}

# ============================================================================
# 三个日志源的集中归档设施
# ============================================================================

module "log_destination_rds" {
  source = "./modules/log_destination"

  service_name               = "rds"
  environment                = var.environment
  region                     = var.region
  access_logs_bucket         = huaweicloud_obs_bucket.access_logs.bucket
  source_account_ids         = var.source_account_ids
  log_processor_function_urn = huaweicloud_fgs_function.log_processor.urn
}

module "log_destination_cce" {
  source = "./modules/log_destination"

  service_name               = "cce"
  environment                = var.environment
  region                     = var.region
  access_logs_bucket         = huaweicloud_obs_bucket.access_logs.bucket
  source_account_ids         = var.source_account_ids
  log_processor_function_urn = huaweicloud_fgs_function.log_processor.urn
}

module "log_destination_function" {
  source = "./modules/log_destination"

  service_name               = "function"
  environment                = var.environment
  region                     = var.region
  access_logs_bucket         = huaweicloud_obs_bucket.access_logs.bucket
  source_account_ids         = var.source_account_ids
  log_processor_function_urn = huaweicloud_fgs_function.log_processor.urn
}
