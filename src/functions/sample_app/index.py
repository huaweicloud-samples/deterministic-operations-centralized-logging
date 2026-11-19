"""
FunctionGraph 示例业务函数
============================

应用账号侧的示例业务函数,对应被集中观测的普通应用函数。
函数运行日志经 LTS 统一采集后,由跨账号转储链路归档到日志归档账号。

任何业务函数都可以放在这里;本文件仅作最小可运行示例。
"""

import json
import logging

logger = logging.getLogger(__name__)


def handler(event, context):
    """FunctionGraph 函数入口(FunctionGraph 标准入口签名)。"""
    logger.info("Received event: %s", json.dumps(event, ensure_ascii=False))
    body = {"statusCode": 200, "body": json.dumps({"message": "Hello from application function"})}
    return body


if __name__ == "__main__":
    print(json.dumps(handler({}, None)))