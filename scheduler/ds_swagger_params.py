#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ds_swagger_params.py  打印指定接口的参数定义"""
import json
import os
import urllib.request
import http.cookiejar

BASE = os.environ.get("DS_BASE", "http://192.168.150.102:12345/dolphinscheduler")
jar = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
with opener.open(BASE + "/v2/api-docs", timeout=25) as r:
    doc = json.loads(r.read().decode("utf-8", "ignore"))

for path in ["/projects/{projectCode}/executors/start-process-instance",
             "/projects/{projectCode}/executors/execute"]:
    node = doc["paths"].get(path, {})
    for method, spec in node.items():
        print("=" * 70)
        print(method.upper(), path, "-", spec.get("summary", ""))
        for p in spec.get("parameters", []):
            print("   %-28s %-10s required=%-5s" % (
                p.get("name"), p.get("in"), p.get("required")))
