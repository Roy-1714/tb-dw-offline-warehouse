#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ds_build_workflow.py  用 DolphinScheduler 2.0.5 REST API 创建 10 节点工作流
用法：
  python ds_build_workflow.py            # 创建 + 上线
  python ds_build_workflow.py --dry-run  # 只打印将要提交的 payload
环境变量：DS_BASE(默认 http://192.168.150.102:12345/dolphinscheduler)、DS_USER、DS_PWD
"""
import json
import os
import sys
import urllib.parse
import urllib.request
import http.cookiejar

DS_BASE = os.environ.get("DS_BASE", "http://192.168.150.102:12345/dolphinscheduler")
DS_USER = os.environ.get("DS_USER", "admin")
DS_PWD = os.environ.get("DS_PWD", "admin123")

PROJECT_NAME = os.environ.get("DS_PROJECT", "tb_dw")
PROCESS_NAME = "tb_dw_daily_etl"
TENANT = "atguigu"
SCRIPT_DIR = "/home/atguigu/offline-dw/script"

# (任务名, 脚本, 是否需要 do_date 参数)
NODES = [
    ("01_ods_load",                "01_ods_load.sh",               False),
    ("02_dim_date_init",           "02_dim_date_init.sh",          False),
    ("03_dwd_detail_1d",           "03_dwd_detail_1d.sh",          True),
    ("04_dim_item",                "04_dim_item.sh",               False),
    ("05_dws_user_1d",             "05_dws_user_1d.sh",            True),
    ("06_dws_item_category_1d",    "06_dws_item_category_1d.sh",   True),
    ("07_dws_nd_td",               "07_dws_nd_td.sh",              True),
    ("08_ads_core_1d",             "08_ads_core_1d.sh",            True),
    ("09_ads_topic_1d",            "09_ads_topic_1d.sh",           True),
    ("10_export_mysql",            "10_export_mysql.sh",           False),
]
BASE_CODE = 7710000000000


def build_payload():
    tasks, relations, locations = [], [], {}
    for i, (name, script, need_date) in enumerate(NODES):
        code = BASE_CODE + i + 1
        cmd = "bash %s/%s" % (SCRIPT_DIR, script)
        if need_date:
            cmd += " ${do_date}"
        tasks.append({
            "code": code,
            "name": name,
            "version": 1,
            "description": "",
            "delayTime": 0,
            "taskType": "SHELL",
            "taskParams": {
                "resourceList": [],
                "localParams": [],
                "rawScript": cmd,
                "conditionResult": {"successNode": [""], "failedNode": [""]},
                "dependence": {},
            },
            "flag": "YES",
            "taskPriority": "MEDIUM",
            "workerGroup": "default",
            "environmentCode": -1,
            "failRetryTimes": 0,
            "failRetryInterval": 1,
            "timeout": 0,
            "timeoutFlag": "CLOSE",
            "timeoutNotifyStrategy": "WARN",
        })
        relations.append({
            "name": "",
            "preTaskCode": 0 if i == 0 else BASE_CODE + i,
            "postTaskCode": code,
            "conditionType": "NONE",
        })
        locations[str(code)] = {
            "name": name, "targetarr": "", "x": 120 + i * 150, "y": 200,
            "nodewarn": 0, "isError": False,
        }
    return {
        "name": PROCESS_NAME,
        "description": "淘宝用户行为离线数仓：ODS->DWD->DWS->ADS->导出，10 节点串行",
        "globalParams": json.dumps([{
            "prop": "do_date", "direct": "IN", "type": "VARCHAR",
            "value": "$[yyyy-MM-dd]", "desc": "业务日期，回溯时手动覆盖",
        }], ensure_ascii=False),
        "tasks": json.dumps(tasks, ensure_ascii=False),
        "taskRelationJson": json.dumps(relations, ensure_ascii=False),
        "locations": json.dumps(locations, ensure_ascii=False),
        "tenantCode": TENANT,
        "timeout": 0,
        "executionType": "PARALLEL",
    }


class DSClient:
    def __init__(self):
        self.jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.jar))

    def _req(self, method, path, data=None, form=False):
        url = DS_BASE + path
        headers = {}
        body = None
        if data is not None:
            if form:
                body = urllib.parse.urlencode(data).encode()
                headers["Content-Type"] = "application/x-www-form-urlencoded"
            else:
                body = json.dumps(data, ensure_ascii=False).encode("utf-8")
                headers["Content-Type"] = "application/json;charset=UTF-8"
        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        with self.opener.open(req, timeout=30) as r:
            return json.loads(r.read().decode("utf-8"))

    def login(self):
        res = self._req("POST", "/login", {"userName": DS_USER, "userPassword": DS_PWD}, form=True)
        if not res.get("success"):
            raise SystemExit("登录失败: %s" % res)
        print("[OK] 登录成功 sessionId=%s" % res["data"]["sessionId"])
        return res["data"]["sessionId"]

    def ensure_project(self, name):
        res = self._req("GET", "/projects?searchVal=%s&pageNo=1&pageSize=20"
                        % urllib.parse.quote(name))
        for p in (res.get("data") or {}).get("totalList", []) or []:
            if p["name"] == name:
                print("[OK] 复用项目 %s code=%s" % (name, p["code"]))
                return p["code"]
        res = self._req("POST", "/projects",
                        {"projectName": name, "description": "淘宝用户行为离线数仓"}, form=True)
        if not res.get("success"):
            raise SystemExit("建项目失败: %s" % res)
        print("[OK] 创建项目 code=%s" % res["data"]["code"])
        return res["data"]["code"]

    def create_process(self, project_code, payload):
        # DS 2.0.5 用 @RequestParam，全部走表单
        form = {
            "name": payload["name"],
            "description": payload["description"],
            "globalParams": payload["globalParams"],
            # DS 2.0.5 的必填参数名是 taskDefinitionJson（不是 tasks）
            "taskDefinitionJson": payload["tasks"],
            "taskRelationJson": payload["taskRelationJson"],
            "locations": payload["locations"],
            "tenantCode": payload["tenantCode"],
            "timeout": str(payload["timeout"]),
            "executionType": payload["executionType"],
        }
        res = self._req("POST", "/projects/%s/process-definition" % project_code, form, form=True)
        if not res.get("success"):
            raise SystemExit("建流程失败: %s" % json.dumps(res, ensure_ascii=False))
        code = res["data"]["code"]
        print("[OK] 创建流程 %s code=%s" % (payload["name"], code))
        return code

    def release(self, project_code, code):
        res = self._req("POST", "/projects/%s/process-definition/%s/release" % (project_code, code),
                        {"releaseState": "ONLINE"}, form=True)
        print("[%s] 上线流程: %s" % ("OK" if res.get("success") else "WARN", res.get("msg")))
        return res


def main():
    payload = build_payload()
    if "--dry-run" in sys.argv:
        print(json.dumps(payload, ensure_ascii=False, indent=2)[:3000])
        return
    c = DSClient()
    c.login()
    pc = c.ensure_project(PROJECT_NAME)
    code = c.create_process(pc, payload)
    c.release(pc, code)
    print("\nprojectCode=%s processDefinitionCode=%s" % (pc, code))


if __name__ == "__main__":
    main()
