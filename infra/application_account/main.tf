# ============================================================================
# 应用账号(Application Account)
#   共享 VPC + 跨账号委托 + 三个日志源模块(RDS / CCE / FunctionGraph)
#   每个日志源:日志进入 LTS 日志组,再经跨账号委托转储到日志归档账号的 OBS
# ============================================================================

# 跨账号委托:LTS 通过该委托把日志写入日志归档账号的中央 OBS 桶
resource "huaweicloud_identity_agency" "cross_account_log_archive" {
  name                  = "${var.environment}-${var.account_name}-log-archive-agency"
  description           = "Agency for LTS to write logs to the log archive account OBS buckets"
  duration              = "FOREVER"
  delegated_domain_name = var.archive_domain_name

  project_role {
    project = var.region
    roles = [
      "OBS OperateAccess",
    ]
  }
}

# CCE 集群前置委托:华为云 CCE 创建集群要求在账号中已存在 cce_admin_trust 委托
resource "huaweicloud_identity_agency" "cce_admin_trust" {
  name                   = "cce_admin_trust"
  description            = "Agency required by CCE to create clusters"
  duration               = "FOREVER"
  delegated_service_name = "op_svc_cce"

  domain_roles = ["CCE FullAccess"]
}

# 共享 VPC
resource "huaweicloud_vpc" "main" {
  name = "${var.account_name}-vpc"
  cidr = var.vpc_config.vpc_cidr
}

resource "huaweicloud_vpc_subnet" "private" {
  count      = length(var.vpc_config.private_subnets)
  name       = "${var.account_name}-private-${count.index}"
  vpc_id     = huaweicloud_vpc.main.id
  cidr       = var.vpc_config.private_subnets[count.index]
  gateway_ip = cidrhost(var.vpc_config.private_subnets[count.index], 1)
}

resource "huaweicloud_vpc_subnet" "public" {
  count      = length(var.vpc_config.public_subnets)
  name       = "${var.account_name}-public-${count.index}"
  vpc_id     = huaweicloud_vpc.main.id
  cidr       = var.vpc_config.public_subnets[count.index]
  gateway_ip = cidrhost(var.vpc_config.public_subnets[count.index], 1)
}

# 应用安全组
resource "huaweicloud_networking_secgroup" "app" {
  name        = "${var.account_name}-app-sg"
  description = "Security group for application account resources"
}

# ============================================================================
# 日志源模块
# ============================================================================

module "rds_logging" {
  source = "./modules/rds_logging"

  environment    = var.environment
  account_name   = var.account_name
  region         = var.region
  rds_config     = var.rds_config
  rds_parameters = var.rds_parameters

  vpc_id                      = huaweicloud_vpc.main.id
  subnet_id                   = huaweicloud_vpc_subnet.private[0].id
  ingress_allowed_cidr_blocks = var.ingress_allowed_cidr_blocks
  egress_allowed_cidr_blocks  = var.egress_allowed_cidr_blocks

  destination_name   = var.destination_name
  archive_obs_bucket = var.archive_obs_buckets["rds"]
  agency_name        = huaweicloud_identity_agency.cross_account_log_archive.name
  agency_domain_id   = var.agency_domain_id
  agency_domain_name = var.agency_domain_name
  agency_project_id  = var.agency_project_id

  tags = var.tags
}

module "cce_logging" {
  source = "./modules/cce_logging"

  environment       = var.environment
  account_name      = var.account_name
  region            = var.region
  cce_config        = var.cce_config
  vpc_id            = huaweicloud_vpc.main.id
  subnet_ids        = concat(huaweicloud_vpc_subnet.private[*].id, huaweicloud_vpc_subnet.public[*].id)
  security_group_id = huaweicloud_networking_secgroup.app.id

  destination_name   = var.destination_name
  archive_obs_bucket = var.archive_obs_buckets["cce"]
  agency_name        = huaweicloud_identity_agency.cross_account_log_archive.name
  agency_domain_id   = var.agency_domain_id
  agency_domain_name = var.agency_domain_name
  agency_project_id  = var.agency_project_id

  tags = var.tags
}

module "function_logging" {
  source = "./modules/function_logging"

  environment     = var.environment
  account_name    = var.account_name
  region          = var.region
  function_config = var.function_config

  destination_name   = var.destination_name
  archive_obs_bucket = var.archive_obs_buckets["function"]
  agency_name        = huaweicloud_identity_agency.cross_account_log_archive.name
  agency_domain_id   = var.agency_domain_id
  agency_domain_name = var.agency_domain_name
  agency_project_id  = var.agency_project_id

  tags = var.tags
}