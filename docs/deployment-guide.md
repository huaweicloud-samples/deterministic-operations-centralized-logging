# 部署指导书

本实践由**两套独立 Terraform 工作区**组成,部署顺序为「日志归档账号 → 应用账号」:

1. 先在日志归档账号创建中央 OBS 桶与日志处理函数;
2. 再在应用账号创建日志源与跨账号转储(转储目标引用归档账号输出)。

## 0. 前置条件

- Terraform CLI >= 1.5
- 两个华为云账号(至少 1 个应用账号 + 1 个日志归档账号),均已完成实名认证
- 两账号的 Access Key(AK/SK),建议通过环境变量提供:
  ```bash
  export HW_ACCESS_KEY="<ACCESS_KEY>"
  export HW_SECRET_KEY="<SECRET_KEY>"
  ```
- 归档账号的**账号域名**(我的凭证页面可见),配置跨账号委托时使用

## 1. 部署日志归档账号

```bash
cd infra/log_archive_account

cp terraform.tfvars.example terraform.tfvars
# 编辑 terraform.tfvars:
#   environment        = "prod"
#   destination_name   = "central-logs"
#   agency_domain_name = "<归档账号域名>"
#   source_account_ids = ["<应用账号 ID>", ...]

terraform init
terraform plan
terraform apply
```

apply 完成后记录输出中的中央桶名(三个服务的 `central_buckets`):

```text
central_buckets = {
  "cce"      = "prod-cn-north-4-cce-logs"
  "function" = "prod-cn-north-4-function-logs"
  "rds"      = "prod-cn-north-4-rds-logs"
}
```

## 2. 部署应用账号

```bash
cd infra/application_account

cp terraform.tfvars.example terraform.tfvars
# 编辑 terraform.tfvars:
#   account_name         = "app-1"
#   destination_name     = "central-logs"     # 与归档账号一致
#   archive_obs_buckets  = { rds = "prod-cn-north-4-rds-logs", cce = "...", function = "..." }
#   archive_domain_name  = "<归档账号域名>"
#   agency_domain_id     = "<本账号 domain ID>"
#   agency_domain_name   = "<本账号域名>"
#   agency_project_id    = "<本账号项目 ID>"
#   rds_config / cce_config / vpc_config 按需调整

terraform init
terraform plan
terraform apply
```

> 说明:跨账号委托在应用账号创建,归档账号桶策略已允许对应账号 ID 写入。若你有多个应用账号,为每个账号复制一套 `infra/application_account` 并以独立 `account_name` / `terraform.tfvars` 部署即可。

## 3. 验证

详见 README「使用方法 / 验证」章节:在应用账号 LTS 检索产生的日志;确认归档账号 OBS 桶中出现按小时归档的日志对象;触发一次日志处理函数并观察登记结果。

## 4. 清理资源

按部署逆序清理:

```bash
# 1) 应用账号
cd infra/application_account
terraform destroy

# 2) 日志归档账号(先清空中央日志桶内对象)
cd infra/log_archive_account
terraform destroy
```

> 中央 OBS 桶开启版本化与生命周期,销毁前请确保已按需导出/备份其中对象,避免数据残留或误删。