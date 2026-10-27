#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ds_probe_docs.py  通过 swagger/api 元数据找执行接口"""
import json
import os
import urllib.error
import urllib.parse
import urllib.request
import http.cookiejar

BASE = os.environ.get("DS_BASE", "http://192.168.150.102:12345/dolphinscheduler")
jar = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))


def get(path):
    req = urllib.request.Request(BASE + path, method="GET")
    try:
        with opener.open(req, timeout=20) as r:
            return r.status, r.read().decode("utf-8", "ignore")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "ignore")
    except Exception as e:
        return -1, str(e)


def post(path, data):
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(BASE + path, data=body, method="POST",
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with opener.open(req, timeout=20) as r:
            return r.status, r.read().decode("utf-8", "ignore")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "ignore")
    except Exception as e:
        return -1, str(e)


post("/login", {"userName": "admin", "userPassword": "admin123"})

for p in ["/v2/api-docs", "/swagger-resources", "/actuator/info", "/version"]:
    st, body = get(p)
    print("GET %-22s -> %s %s" % (p, st, body[:120].replace("\n", " ")))

st, body = get("/v2/api-docs")
if st == 200:
    try:
        doc = json.loads(body)
        keys = [k for k in doc.get("paths", {}) if "execut" in k or "process-instances" in k]
        print("\n相关路径:")
        for k in sorted(keys):
            print("  ", k, list(doc["paths"][k].keys()))
    except Exception as e:
        print("解析失败", e)
