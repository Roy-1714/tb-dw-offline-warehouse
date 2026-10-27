#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ds_dump_definition.py  导出已上线的工作流定义，作为仓库内的可核查产物"""
import json
import os
import sys
import urllib.request
import http.cookiejar

DS_BASE = os.environ.get("DS_BASE", "http://192.168.150.102:12345/dolphinscheduler")
PROJECT_CODE = os.environ.get("DS_PROJECT_CODE", "23464296537888")
PROC_CODE = os.environ.get("DS_PROC_CODE", "23465045574688")
OUT = os.environ.get("OUT", os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         "process_definition_export.json"))


def main():
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))

    def call(method, path, data=None):
        body = None
        headers = {}
        if data is not None:
            body = urllib.parse.urlencode(data).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        req = urllib.request.Request(DS_BASE + path, data=body, headers=headers, method=method)
        with opener.open(req, timeout=30) as r:
            return json.loads(r.read().decode("utf-8"))

    call("POST", "/login", {"userName": "admin", "userPassword": "admin123"})
    res = call("GET", "/projects/%s/process-definition/%s" % (PROJECT_CODE, PROC_CODE))
    if not res.get("success"):
        raise SystemExit("获取定义失败: %s" % res)
    data = res["data"] or {}
    # 兼容两种返回结构：直接是定义对象，或 {processDefinition:..., taskDefinitionList:[...]}
    definition = data.get("processDefinition") or data
    tasks = data.get("taskDefinitionList") or []
    if not tasks:
        tres = call("GET", "/projects/%s/process-definition/%s/tasks" % (PROJECT_CODE, PROC_CODE))
        tasks = tres.get("data") or []
    payload = {"processDefinition": definition, "taskDefinitionList": tasks}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    print("已导出: %s" % OUT)
    print("流程名: %s  状态: %s  节点数: %d" % (
        definition.get("name"), definition.get("releaseState"), len(tasks)))
    for i, t in enumerate(tasks, 1):
        script = (t.get("taskParams") or {}).get("rawScript", "")
        print("  %2d. %-26s %s" % (i, t.get("name"), script))


if __name__ == "__main__":
    import urllib.parse
    main()
