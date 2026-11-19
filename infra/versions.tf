# 根级 provider 版本约束（各子工作区继承使用）
# 本仓库为多账号双 workspace 结构：
#   infra/application_account/  — 应用账号日志源 + LTS + 跨账号转储
#   infra/log_archive_account/  — 日志归档账号中央 OBS + 处理函数
# 各 workspace 独立 init/plan/apply，本文件仅声明共享版本约束。

terraform {
  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.70"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  required_version = ">= 1.5"
}
