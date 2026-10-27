#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ds_probe_api.py  探测 DS 2.0.5 的执行接口路径"""
import json
import os
import urllib.error
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
    try:
        with opener.open(req, timeout=20) as r:
            return r.status, r.read().decode("utf-8")[:200]
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8")[:200]
    except Exception as e:
        return -1, str(e)[:200]


call("POST", "/login", {"userName": "admin", "userPassword": "admin123"})

candidates = [
    ("POST", "/projects/%s/executions" % PC),
    ("POST", "/projects/%s/executions/" % PC),
    ("POST", "/projects/%s/execution" % PC),
    ("GET",  "/projects/%s/executions?pageNo=1&pageSize=5" % PC),
    ("GET",  "/projects/%s/executions/list?pageNo=1&pageSize=5" % PC),
    ("POST", "/projects/%s/process-instances" % PC),
    ("GET",  "/projects/%s/process-instances?pageNo=1&pageSize=5" % PC),
]
for m, p in candidates:
    st, body = call(m, p)
    print("%-5s %-55s -> %s %s" % (m, p, st, body.replace("\n", " ")[:110]))
