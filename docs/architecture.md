# 架构说明

## 1. 总体架构

本实践构建一套**跨账号的企业级集中式日志管治体系**:多个应用账号内的云服务日志(关系型数据库、Kubernetes 容器、函数计算)自动汇聚到独立的日志归档账号,统一加密存储、长期留存并触发后续处理。

```
┌──────────────────────────── 应用账号(1..n) ────────────────────────────┐
│                                                                        │
│    ┌──────────┐    ┌──────────────┐    ┌──────────────────┐            │
│    │ RDS MySQL │    │   CCE 集群   │    │  FunctionGraph   │            │
│    │ 参数组开启 │    │ 控制面日志    │    │  示例业务函数     │            │
│    │ 错误/慢/审计│    │ VPC 流日志   │    │  运行日志         │            │
│    └────┬─────┘    └──────┬───────┘    └────────┬─────────┘            │
│         │                 │                     │                     │
│         ▼                 ▼                     ▼                     │
│    ┌─────────────────────── LTS 日志组/流 ───────────────────────┐      │
│    │  rds / cce / function 三类日志各自汇聚,留存 365 天            │      │
│    └──────────────────────────────┬──────────────────────────────┘      │
│                                   │  IAM 委托(跨账号)                   │
│                                   ▼                                     │
│                 LTS 跨账号转储(周期写对象,SSE 加密)                      │
└───────────────────────────────────┼─────────────────────────────────────┘
                                    │
┌────────────────────────── 日志归档账号 ────────────────────────────┐
│                                    ▼                               │
│    ┌────────────────────── 中央 OBS 日志桶 ──────────────────────┐  │
│    │  rds-logs / cce-logs / function-logs                       │  │
│    │  SSE-KMS 加密 + 版本化 + 私有                               │  │
│    │  生命周期:30天→低频 / 60天→归档 / 7年过期                    │  │
│    │  访问日志 → 共享 access-logs 桶                              │  │
│    └──────────────────────────────┬──────────────────────────────┘  │
│                                   │ OBS 事件通知(ObjectCreated)      │
│                                   ▼                                 │
│                      FunctionGraph 日志处理函数                      │
│                      (登记新日志对象,进一步处理扩展点)                 │
└──────────────────────────────────────────────────────────────────────┘
```

## 2. 组件职责

### 2.1 应用账号侧

| 组件 | 职责 | Terraform 资源 |
|---|---|---|
| RDS for MySQL 日志源 | 参数组开启 `general_log` / `slow_query_log` / `log_output=FILE` / `require_secure_transport`;实例以主备高可用部署;错误/慢查询/审计日志接入 LTS | `huaweicloud_rds_parametergroup`、`huaweicloud_rds_instance`、`huaweicloud_rds_lts_config` |
| CCE 集群日志源 | 集群控制面日志(kube-apiserver / audit / controller-manager / scheduler)接入 LTS;VPC 流日志接入 LTS | `huaweicloud_cce_cluster`、`huaweicloud_cce_cluster_log_config`、`huaweicloud_vpc_flow_log` |
| FunctionGraph 日志源 | 示例业务函数(任何应用函数皆可替换);启用 LTS 日志能力,函数日志统一汇聚 | `huaweicloud_fgs_function`、`huaweicloud_fgs_lts_log_enable` |
| LTS 日志组/流 | 每类日志源独立日志组(rds / cce / function),留存 365 天 | `huaweicloud_lts_group`、`huaweicloud_lts_stream` |
| 跨账号转储 | IAM 委托授权 LTS 把日志写入归档账号的中央 OBS 桶 | `huaweicloud_identity_agency`、`huaweicloud_lts_transfer` |

### 2.2 日志归档账号侧

| 组件 | 职责 | Terraform 资源 |
|---|---|---|
| 中央 OBS 日志桶 | 每类日志源一个中央桶,SSE-KMS 加密、开启版本化、私有访问;生命周期 30 天转低频、60 天转归档、7 年过期 | `huaweicloud_obs_bucket`(含 `lifecycle_rule`) |
| 访问日志桶 | 记录对中央日志桶的访问行为(共享 access-logs 桶,版本化 + 私有) | `huaweicloud_obs_bucket` + `logging` 块 |
| 桶策略 | 仅允许白名单中的应用账号(经 LTS 委托)写入日志对象 | `huaweicloud_obs_bucket_policy` |
| 日志处理函数 | 中央桶新对象落盘触发,登记日志对象信息,作为「进一步处理」扩展点 | `huaweicloud_fgs_function` + `huaweicloud_fgs_trigger`(OBS 事件) |

## 3. 日志数据流

1. 应用账号内的 RDS / CCE / FunctionGraph 产生运行日志。
2. 日志实时写入应用账号 LTS 日志组(每类日志源独立,留存 365 天,应用账号本地可检索)。
3. LTS 转储任务按周期(默认 1 小时)将日志对象写入日志归档账号的中央 OBS 桶,写入经 IAM 委托完成跨账号授权,对象以 SSE-KMS 加密。
4. 归档账号 OBS 桶策略限定仅白名单应用账号可写入,桶开启版本化与生命周期管理,30 天转低频、60 天转归档、7 年过期;所有访问行为记入 access-logs 桶。
5. 新日志对象落盘触发 FunctionGraph 日志处理函数,对日志对象做登记(可扩展为解析、告警、入湖等处理)。

## 4. 关键设计

- **跨账号最小权限**:应用账号创建 IAM 委托,仅授权 OBS 写入;归档账号桶策略再次限定账号白名单,形成双重约束。
- **加密贯穿**:日志在 LTS 与 OBS 均启用加密,中央桶对象转储时按 KMS 密钥加密。
- **长期留存与分层**:归档账号统一执行「低频 → 归档 → 过期」生命周期,避免日志无限膨胀,7 年后自动清理。
- **可扩展处理**:日志落盘事件驱动 FunctionGraph,后续可扩展为解析、汇总、告警或入湖分析,无需改动采集链路。

## 5. 目录结构

```
infra/
├── application_account/          # 应用账号 IaC(每账号一套)
│   ├── main.tf                   # VPC / 委托 / 三日志源模块编排
│   ├── modules/
│   │   ├── rds_logging/          # RDS 日志源
│   │   ├── cce_logging/          # CCE 日志源
│   │   └── function_logging/     # FunctionGraph 日志源
│   └── functions/sample_app/     # 示例业务函数
└── log_archive_account/          # 日志归档账号 IaC
    ├── main.tf                   # 共享访问日志桶 / 处理函数
    ├── triggers.tf               # OBS 事件触发器
    └── modules/log_destination/  # 每日志源的中央桶
src/functions/                    # 函数源码基准副本
    ├── log_processor/            # 日志处理函数
    └── sample_app/               # 示例业务函数
```