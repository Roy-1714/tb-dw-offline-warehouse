#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ds_run_workflow.py  触发 DolphinScheduler 工作流并轮询状态
用法：
  python ds_run_workflow.py --date 2017-12-03
  python ds_run_workflow.py --status-only
"""
import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import http.cookiejar

DS_BASE = os.environ.get("DS_BASE", "http://192.168.150.102:12345/dolphinscheduler")
DS_USER = os.environ.get("DS_USER", "admin")
DS_PWD = os.environ.get("DS_PWD", "admin123")
PROJECT_CODE = os.environ.get("DS_PROJECT_CODE", "23464296537888")
PROC_CODE = os.environ.get("DS_PROC_CODE", "23465045574688")


class DS:
    def __init__(self):
        self.jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.jar))

    def call(self, method, path, data=None):
        body = None
        headers = {}
        if data is not None:
            body = urllib.parse.urlencode(data).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        req = urllib.request.Request(DS_BASE + path, data=body, headers=headers, method=method)
        with self.opener.open(req, timeout=30) as r:
            return json.loads(r.read().decode("utf-8"))

    def login(self):
        res = self.call("POST", "/login", {"userName": DS_USER, "userPassword": DS_PWD})
        if not res.get("success"):
            raise SystemExit("登录失败: %s" % res)

    def instances(self, size=10):
        res = self.call("GET", "/projects/%s/process-instances?pageNo=1&pageSize=%d"
                        % (PROJECT_CODE, size))
        return (res.get("data") or {}).get("totalList", []) or []

    def run(self, do_date, start_node=""):
        form = {
            "processDefinitionCode": PROC_CODE,
            "scheduleTime": "",
            "failureStrategy": "CONTINUE",
            "startNodeList": start_node,
            "taskDependType": "TASK_POST" if start_node else "TASK_POST",
            "execType": "START_PROCESS",
            "warningType": "NONE",
            "warningGroupId": "0",
            "runMode": "RUN_MODE_SERIAL",
            "processInstancePriority": "MEDIUM",
            "workerGroup": "default",
            "environmentCode": "-1",
            "startParams": json.dumps({"do_date": do_date}),
            "expectedParallelismNumber": "",
            "dryRun": "0",
        }
        res = self.call("POST", "/projects/%s/executors/start-process-instance" % PROJECT_CODE, form)
        print("触发结果: %s" % json.dumps(res, ensure_ascii=False))
        return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--date", default="2017-12-03")
    ap.add_argument("--start-node", default="", help="从指定节点开始补跑，如 08_ads_core_1d")
    ap.add_argument("--status-only", action="store_true")
    ap.add_argument("--watch", action="store_true", help="轮询直到结束")
    a = ap.parse_args()

    ds = DS()
    ds.login()

    if not a.status_only:
        ds.run(a.date, a.start_node)

    if a.status_only or a.watch:
        for i in range(240):
            rows = ds.instances(5)
            if not rows:
                print("暂无流程实例")
                return
            r = rows[0]
            print("[%s] id=%s state=%s 开始=%s 结束=%s" % (
                time.strftime("%H:%M:%S"), r.get("id"), r.get("state"),
                r.get("startTime"), r.get("endTime")))
            if r.get("state") in ("SUCCESS", "FAILURE", "STOP", "KILL"):
                print("结束，最终状态: %s" % r.get("state"))
                return
            if not a.watch:
                return
            time.sleep(15)


if __name__ == "__main__":
    main()
