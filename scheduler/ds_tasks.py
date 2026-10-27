#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ds_tasks.py  打印流程实例下每个任务的状态（兼容不同返回结构）"""
import json
import os
import sys
import urllib.parse
import urllib.request
import http.cookiejar

BASE = os.environ.get("DS_BASE", "http://192.168.150.102:12345/dolphinscheduler")
PC = "23464296537888"
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

pid = sys.argv[1] if len(sys.argv) > 1 else None
if not pid:
    rows = (call("GET", "/projects/%s/process-instances?pageNo=1&pageSize=1" % PC)
            .get("data") or {}).get("totalList") or []
    pid = rows[0]["id"]
    print("实例:", rows[0]["id"], rows[0]["state"])

res = call("GET", "/projects/%s/process-instances/%s/tasks" % (PC, pid))
data = res.get("data")
print("data 类型:", type(data).__name__)
if isinstance(data, dict):
    for k, v in data.items():
        print(" key:", k, type(v).__name__)
    data = data.get("taskList") or data.get("totalList") or []
if isinstance(data, list):
    for t in data:
        if isinstance(t, dict):
            print("%-28s %-18s %s -> %s" % (t.get("name"), t.get("state"),
                                            t.get("startTime"), t.get("endTime")))
        else:
            print("  ", str(t)[:120])
