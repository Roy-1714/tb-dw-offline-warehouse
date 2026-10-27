#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ds_control.py  停止指定流程实例 / 触发整条工作流
用法：
  python ds_control.py stop <processInstanceId>
  python ds_control.py run <do_date>
"""
import json
import os
import sys
import urllib.parse
import urllib.request
import http.cookiejar

BASE = os.environ.get("DS_BASE", "http://192.168.150.102:12345/dolphinscheduler")
PC = "23464296537888"
PROC = "23465045574688"
jar = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))


def call(method, path, data=None):
    body = None
    headers = {}
    if data is not None:
        body = urllib.parse.urlencode(data).encode()
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    req = urllib.request.Request(BASE + path, data=body, headers=headers, method=method)
    with opener.open(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


call("POST", "/login", {"userName": "admin", "userPassword": "admin123"})
action = sys.argv[1]

if action == "stop":
    pid = sys.argv[2]
    res = call("POST", "/projects/%s/executors/execute" % PC, {
        "executeType": "STOP", "processInstanceId": pid})
    print("停止结果:", json.dumps(res, ensure_ascii=False))
elif action == "run":
    date = sys.argv[2]
    res = call("POST", "/projects/%s/executors/start-process-instance" % PC, {
        "processDefinitionCode": PROC,
        "scheduleTime": "",
        "failureStrategy": "CONTINUE",
        "startNodeList": "",
        "taskDependType": "TASK_POST",
        "execType": "START_PROCESS",
        "warningType": "NONE",
        "warningGroupId": "0",
        "runMode": "RUN_MODE_SERIAL",
        "processInstancePriority": "MEDIUM",
        "workerGroup": "default",
        "environmentCode": "-1",
        "startParams": json.dumps({"do_date": date}),
        "dryRun": "0",
    })
    print("触发结果:", json.dumps(res, ensure_ascii=False))
else:
    print("用法: stop <id> | run <date>")
