#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ds_ui_facts.py  确认 web 端能看到的对象（项目/工作流/实例）"""
import json
import os
import urllib.parse
import urllib.request
import http.cookiejar

BASE = os.environ.get("DS_BASE", "http://192.168.150.102:12345/dolphinscheduler")
jar = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))


def call(method, path, data=None):
    body = None
    headers = {}
    if data is not None:
        body = urllib.parse.urlencode(data).encode()
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    req = urllib.request.Request(BASE + path, data=body, headers=headers, method=method)
    with opener.open(req, timeout=25) as r:
        return json.loads(r.read().decode("utf-8"))


call("POST", "/login", {"userName": "admin", "userPassword": "admin123"})

ps = (call("GET", "/projects?searchVal=&pageNo=1&pageSize=20").get("data") or {}).get("totalList") or []
for p in ps:
    print("项目: %s  code=%s" % (p.get("name"), p.get("code")))
    ds = (call("GET", "/projects/%s/process-definition?pageNo=1&pageSize=20" % p["code"])
          .get("data") or {}).get("totalList") or []
    for d in ds:
        print("   工作流: %s  code=%s  状态=%s  版本=%s" % (
            d.get("name"), d.get("code"), d.get("releaseState"), d.get("version")))
    ins = (call("GET", "/projects/%s/process-instances?pageNo=1&pageSize=10" % p["code"])
           .get("data") or {}).get("totalList") or []
    for r in ins[:4]:
        print("   实例 %s: %s  %s -> %s" % (
            r.get("id"), r.get("state"), r.get("startTime"), r.get("endTime")))
