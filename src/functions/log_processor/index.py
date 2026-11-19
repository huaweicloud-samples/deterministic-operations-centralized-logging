"""
FunctionGraph 日志处理函数
============================

在日志归档账号侧运行,由 OBS 事件通知触发。
当应用账号的日志经 LTS 转储落盘到中央日志桶后,本函数对新对象做
元数据登记与摘要处理,是「集中日志进一步处理」的示例扩展点。

事件结构遵循 FunctionGraph 的 OBS 触发器规范。
handler 签名保持 handler(event, context) 不变。
"""

import json
import logging
import os

logger = logging.getLogger(__name__)


def handler(event, context):
    """OBS 触发器入口:新日志对象落盘时执行。"""
    try:
        records = event.get("Records", [])
        processed = []
        for record in records:
            if record.get("eventName", "").startswith("ObjectCreated"):
                item = {
                    "bucket": record.get("obs", {}).get("bucket", {}).get("name"),
                    "object_key": record.get("obs", {}).get("object", {}).get("key"),
                    "size": record.get("obs", {}).get("object", {}).get("size"),
                    "action": "register-log-object",
                }
                processed.append(item)
                logger.info("New log object registered: %s/%s",
                            item["bucket"], item["object_key"])
        return {
            "statusCode": 200,
            "body": json.dumps({"processed": processed}, ensure_ascii=False),
        }
    except Exception as exc:  # noqa: BLE001 - 触发侧异常需完整记录
        logger.exception("Failed to process log event")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(exc)}),
        }


if __name__ == "__main__":
    # 本地模拟 OBS 触发器事件
    sample_event = {
        "Records": [
            {
                "eventName": "ObjectCreated:Put",
                "obs": {
                    "bucket": {"name": os.environ.get("LOG_BUCKETS", "demo-bucket")},
                    "object": {"key": "rds/2026/09/29/10/error.log", "size": 1024},
                },
            }
        ]
    }
    print(json.dumps(handler(sample_event, None), ensure_ascii=False))