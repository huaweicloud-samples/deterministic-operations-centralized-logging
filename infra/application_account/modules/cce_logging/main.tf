# ============================================================================
# CCE 集群日志源
#   集群 + 控制面日志 → LTS + VPC 流日志 → LTS → LTS 跨账号转储到归档 OBS
# ============================================================================

locals {
  log_group_name = "${var.destination_name}-cce"
}

# CCE 集群
resource "huaweicloud_cce_cluster" "this" {
  name                   = "${var.cce_config.cluster_name}-${var.account_name}"
  cluster_type           = "VirtualMachine"
  flavor_id              = var.cce_config.flavor_id
  vpc_id                 = var.vpc_id
  subnet_id              = var.subnet_ids[0]
  container_network_type = "overlay_l2"
  cluster_version        = var.cce_config.cluster_version
  security_group_id      = var.security_group_id

  tags = var.tags
}

# 控制面日志:接入 LTS(api-server / audit / controller-manager / scheduler)
resource "huaweicloud_cce_cluster_log_config" "control_plane" {
  cluster_id  = huaweicloud_cce_cluster.this.id
  ttl_in_days = 30

  log_configs {
    name   = "kube-apiserver"
    enable = true
  }
  log_configs {
    name   = "kube-controller-manager"
    enable = true
  }
  log_configs {
    name   = "kube-scheduler"
    enable = true
  }
  log_configs {
    name   = "audit"
    enable = true
  }
}

# LTS 日志组/流:承载 CCE 控制面与容器日志
resource "huaweicloud_lts_group" "cce" {
  group_name  = local.log_group_name
  ttl_in_days = 30
}

resource "huaweicloud_lts_stream" "cce_control" {
  group_id    = huaweicloud_lts_group.cce.id
  stream_name = "${local.log_group_name}-control-plane"
}

# VPC 流日志 → LTS
resource "huaweicloud_lts_stream" "cce_flow" {
  group_id    = huaweicloud_lts_group.cce.id
  stream_name = "${local.log_group_name}-vpc-flow"
}

resource "huaweicloud_vpc_flow_log" "this" {
  name          = "${var.cce_config.cluster_name}-flow-log"
  resource_type = "vpc"
  resource_id   = var.vpc_id
  traffic_type  = "all"
  log_group_id  = huaweicloud_lts_group.cce.id
  log_stream_id = huaweicloud_lts_stream.cce_flow.id
}

# LTS 跨账号转储:经委托把 CCE 日志写入归档账号中央 OBS
resource "huaweicloud_lts_transfer" "to_archive" {
  log_group_id = huaweicloud_lts_group.cce.id

  log_streams {
    log_stream_id = huaweicloud_lts_stream.cce_control.id
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
      obs_dir_prefix_name  = "cce/"
      obs_encrypted_enable = true
    }

    log_agency_transfer {
      agency_domain_id   = var.agency_domain_id
      agency_domain_name = var.agency_domain_name
      agency_name        = var.agency_name
      agency_project_id  = var.agency_project_id
    }
  }

  depends_on = [huaweicloud_cce_cluster_log_config.control_plane]
}

output "cluster_id" {
  value = huaweicloud_cce_cluster.this.id
}

output "log_group_id" {
  value = huaweicloud_lts_group.cce.id
}