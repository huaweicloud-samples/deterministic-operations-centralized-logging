# ============================================================================
# RDS for MySQL 日志源
#   参数组开启数据库日志 → 实例日志接入 LTS → LTS 跨账号转储到归档 OBS
# ============================================================================

locals {
  log_group_name = "${var.destination_name}-rds"
}

# 数据库安全组(安全组为区域级资源)
resource "huaweicloud_networking_secgroup" "rds" {
  name        = "${var.account_name}-rds-sg"
  description = "Security group for RDS instance"
}

resource "huaweicloud_networking_secgroup_rule" "rds_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3306
  port_range_max    = 3306
  remote_ip_prefix  = var.ingress_allowed_cidr_blocks[0]
  security_group_id = huaweicloud_networking_secgroup.rds.id
}

resource "huaweicloud_networking_secgroup_rule" "rds_egress" {
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = var.egress_allowed_cidr_blocks[0]
  security_group_id = huaweicloud_networking_secgroup.rds.id
}

# 数据库日志参数组
resource "huaweicloud_rds_parametergroup" "logging" {
  name        = "${var.account_name}-mysql-logging-pg"
  description = "Parameter group with logging enabled"

  datastore {
    type    = "mysql"
    version = var.rds_config.engine_version
  }

  values = {
    general_log              = tostring(var.rds_parameters.general_log)
    slow_query_log           = tostring(var.rds_parameters.slow_query_log)
    long_query_time          = tostring(var.rds_parameters.long_query_time)
    log_output               = var.rds_parameters.log_output
    require_secure_transport = "1"
  }
}

resource "random_password" "master_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^*-_=+?"
}

# 主实例(主备高可用 + 参数组 + 磁盘加密)
resource "huaweicloud_rds_instance" "this" {
  name              = "${var.account_name}-${var.rds_config.identifier}"
  flavor            = var.rds_config.instance_class
  vpc_id            = var.vpc_id
  subnet_id         = var.subnet_id
  security_group_id = huaweicloud_networking_secgroup.rds.id
  availability_zone = [var.availability_zone_1, var.availability_zone_2]

  db {
    type     = var.rds_config.engine
    version  = var.rds_config.engine_version
    password = random_password.master_password.result
    port     = 3306
  }

  volume {
    type = "CLOUDSSD"
    size = var.rds_config.allocated_storage
  }

  param_group_id      = huaweicloud_rds_parametergroup.logging.id
  ha_replication_mode = "async"

  tags = var.tags
}

variable "availability_zone_1" {
  type    = string
  default = "cn-north-4a"
}

variable "availability_zone_2" {
  type    = string
  default = "cn-north-4b"
}

# LTS 日志组/流:承载 RDS 错误/慢查询/审计日志
resource "huaweicloud_lts_group" "rds" {
  group_name  = local.log_group_name
  ttl_in_days = 365
}

resource "huaweicloud_lts_stream" "rds_error" {
  group_id    = huaweicloud_lts_group.rds.id
  stream_name = "${local.log_group_name}-error"
}

resource "huaweicloud_lts_stream" "rds_slow" {
  group_id    = huaweicloud_lts_group.rds.id
  stream_name = "${local.log_group_name}-slow"
}

# RDS 日志接入 LTS(错误/慢查询/审计)
resource "huaweicloud_rds_lts_config" "error_log" {
  instance_id   = huaweicloud_rds_instance.this.id
  engine        = "mysql"
  log_type      = "error_log"
  lts_group_id  = huaweicloud_lts_group.rds.id
  lts_stream_id = huaweicloud_lts_stream.rds_error.id
}

resource "huaweicloud_rds_lts_config" "slow_log" {
  instance_id   = huaweicloud_rds_instance.this.id
  engine        = "mysql"
  log_type      = "slow_log"
  lts_group_id  = huaweicloud_lts_group.rds.id
  lts_stream_id = huaweicloud_lts_stream.rds_slow.id
}

# LTS 跨账号转储:经委托把 RDS 日志写入归档账号中央 OBS
resource "huaweicloud_lts_transfer" "to_archive" {
  log_group_id = huaweicloud_lts_group.rds.id

  log_streams {
    log_stream_id = huaweicloud_lts_stream.rds_error.id
  }
  log_streams {
    log_stream_id = huaweicloud_lts_stream.rds_slow.id
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
      obs_dir_prefix_name  = "rds/"
      obs_encrypted_enable = true
    }

    log_agency_transfer {
      agency_domain_id   = var.agency_domain_id
      agency_domain_name = var.agency_domain_name
      agency_name        = var.agency_name
      agency_project_id  = var.agency_project_id
    }
  }

  depends_on = [
    huaweicloud_rds_lts_config.error_log,
    huaweicloud_rds_lts_config.slow_log,
  ]
}

output "rds_endpoint" {
  value = huaweicloud_rds_instance.this.private_ips[0]
}

output "log_group_id" {
  value = huaweicloud_lts_group.rds.id
}