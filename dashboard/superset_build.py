#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""superset_build.py  用 Superset REST API 建连接、数据集、图表、看板

用法（在 hadoop102 上用 superset 环境的 python 跑）：
  /opt/module/miniconda3/envs/superset/bin/python superset_build.py step1
  /opt/module/miniconda3/envs/superset/bin/python superset_build.py step2
"""
import json
import sys

import requests

BASE = "http://127.0.0.1:8088"
API = BASE + "/api/v1"
USER = "admin"
PWD = "admin123"

DB_NAME = "tb_dw_report"
SQLALCHEMY_URI = ("mysql+pymysql://root:000000@hadoop102:3306/tb_dw_report"
                  "?charset=utf8mb4")

TABLES = [
    "ads_dau_1d", "ads_funnel_1d", "ads_retention_1d", "ads_hour_active_1d",
    "ads_item_topn_1d", "ads_category_topn_1d", "ads_buy_freq_dist_1d",
    "ads_user_rf_seg_1d", "ads_path_analysis_1d", "ads_item_skew_1d",
]


def login():
    s = requests.Session()
    r = s.post(API + "/security/login",
               json={"username": USER, "password": PWD,
                     "provider": "db", "refresh": True}, timeout=30)
    r.raise_for_status()
    tok = r.json()["access_token"]
    s.headers.update({"Authorization": "Bearer " + tok})
    # Superset 的写操作要 CSRF token + Referer
    c = s.get(API + "/security/csrf_token/", timeout=30)
    c.raise_for_status()
    csrf = c.json()["result"]
    s.headers.update({
        "X-CSRFToken": csrf,
        "Referer": BASE + "/",
        "Content-Type": "application/json",
    })
    return s


def show(s, method, path, **kw):
    r = s.request(method, API + path, timeout=60, **kw)
    ok = r.status_code < 400
    body = r.text[:600].replace("\n", " ")
    print("%-6s %-42s -> %s %s" % (method, path, r.status_code, "" if ok else body))
    return r


def step1(s):
    ver = requests.get(BASE + "/api/v1/version", timeout=20)
    print("Superset:", ver.text[:200])

    # 数据库连接
    r = s.get(API + "/database/?q=(page_size:100)", timeout=30)
    existing = {d["database_name"]: d["id"] for d in r.json().get("result", [])}
    if DB_NAME in existing:
        db_id = existing[DB_NAME]
        print("[OK] 复用数据库连接 id=%s" % db_id)
    else:
        r = show(s, "POST", "/database/", data=json.dumps({
            "database_name": DB_NAME,
            "sqlalchemy_uri": SQLALCHEMY_URI,
            "expose_in_sqllab": True,
            "allow_ctas": False,
            "allow_cvas": False,
            "allow_dml": False,
            "extra": json.dumps({"metadata_params": {}, "engine_params": {}}),
        }))
        if r.status_code >= 400:
            return None
        db_id = r.json()["id"]
        print("[OK] 新建数据库连接 id=%s" % db_id)

    # 测试连接
    show(s, "POST", "/database/test_connection/", data=json.dumps({
        "database_name": DB_NAME, "sqlalchemy_uri": SQLALCHEMY_URI}))

    # 数据集
    r = s.get(API + "/dataset/?q=(page_size:200)", timeout=30)
    have = {d["table_name"]: d["id"] for d in r.json().get("result", [])}
    ids = {}
    for t in TABLES:
        if t in have:
            ids[t] = have[t]
            print("[OK] 复用数据集 %-24s id=%s" % (t, have[t]))
            continue
        r = show(s, "POST", "/dataset/", data=json.dumps({
            "database": db_id, "schema": None, "table_name": t}))
        if r.status_code < 400:
            ids[t] = r.json()["id"]
            print("[OK] 新建数据集 %-24s id=%s" % (t, r.json()["id"]))
    print("\nDB_ID=%s" % db_id)
    print("DATASETS=" + json.dumps(ids))
    return db_id, ids


CHARTS = [
    # (名称, 数据集 key, viz_type, params)
    ("总活跃用户（9 天累计去重前）", "ads_dau_1d", "big_number_total", {
        "datasource": "1__table",
        "viz_type": "big_number_total",
        "metric": "SUM(uv)",
        "adhoc_filters": [],
        "header_font_size": 0.4,
        "subheader_font_size": 0.15,
        "y_axis_format": "SMART_NUMBER",
    }),
    ("每日 UV / PV 趋势", "ads_dau_1d", "table", {
        "datasource": "1__table",
        "viz_type": "table",
        "query_mode": "raw",
        "all_columns": ["dt", "pv", "uv", "buy_uv", "pv_per_uv", "new_uv", "old_uv"],
        "order_by_cols": ["[\"dt\", true]"],
        "row_limit": 20,
    }),
    ("行为漏斗（各环节人数）", "ads_funnel_1d", "table", {
        "datasource": "2__table",
        "viz_type": "table",
        "query_mode": "raw",
        "all_columns": ["dt", "pv_uv", "cart_uv", "fav_uv", "buy_uv",
                        "pv2cart_rate", "cart2buy_rate", "pv2buy_rate"],
        "order_by_cols": ["[\"dt\", true]"],
        "row_limit": 20,
    }),
    ("类目浏览量 Top10（12-02）", "ads_category_topn_1d", "table", {
        "datasource": "6__table",
        "viz_type": "table",
        "query_mode": "raw",
        "all_columns": ["dt", "rk", "category_id", "pv", "uv", "buy_uv"],
        "order_by_cols": ["[\"rk\", true]"],
        "row_limit": 10,
    }),
    ("分时活跃（PV）", "ads_hour_active_1d", "table", {
        "datasource": "4__table",
        "viz_type": "table",
        "query_mode": "raw",
        "all_columns": ["dt", "hour", "pv", "uv"],
        "order_by_cols": ["[\"hour\", true]"],
        "row_limit": 24,
    }),
    ("商品访问集中度（倾斜证据）", "ads_item_skew_1d", "table", {
        "datasource": "10__table",
        "viz_type": "table",
        "query_mode": "raw",
        "all_columns": ["dt", "item_cnt", "pv_total", "top1pct_share", "max_item_share"],
        "order_by_cols": ["[\"dt\", true]"],
        "row_limit": 20,
    }),
]


def step2(s):
    # 先取数据集 id（按表名）
    r = s.get(API + "/dataset/?q=(page_size:200)", timeout=30)
    ds_ids = {d["table_name"]: d["id"] for d in r.json().get("result", [])}
    if not ds_ids:
        raise SystemExit("没有数据集，先跑 step1")

    r = s.get(API + "/chart/?q=(page_size:100)", timeout=30)
    have = {c["slice_name"]: c["id"] for c in r.json().get("result", [])}
    ids = {}
    for name, ds_key, viz, params in CHARTS:
        if name in have:
            ids[name] = have[name]
            print("[OK] 复用图表 %-30s id=%s" % (name, have[name]))
            continue
        ds_id = ds_ids[ds_key]
        p = dict(params)
        p["datasource"] = "%d__table" % ds_id
        body = {
            "slice_name": name,
            "viz_type": viz,
            "datasource_id": ds_id,
            "datasource_type": "table",
            "params": json.dumps(p, ensure_ascii=False),
        }
        r = show(s, "POST", "/chart/", data=json.dumps(body))
        if r.status_code < 400:
            ids[name] = r.json()["id"]
            print("[OK] 新建图表 %-30s id=%s" % (name, r.json()["id"]))
    print("\nCHARTS=" + json.dumps(ids, ensure_ascii=False))
    return ids


DASH_TITLE = "淘宝用户行为数仓看板"
DASH_SLUG = "tb-dw-dashboard"


def step3(s):
    r = s.get(API + "/chart/?q=(page_size:100)", timeout=30)
    charts = {c["slice_name"]: c["id"] for c in r.json().get("result", [])}
    if not charts:
        raise SystemExit("没有图表，先跑 step2")
    names = list(charts.keys())
    cids = [charts[n] for n in names]

    # 2 行 3 列布局
    rows = [cids[0:3], cids[3:6]]
    position = {
        "DASHBOARD_VERSION_KEY": "v2",
        "ROOT_ID": {"type": "ROOT", "id": "ROOT_ID", "children": ["GRID_ID"], "parents": []},
        "GRID_ID": {"type": "GRID", "id": "GRID_ID", "children": [], "parents": ["ROOT_ID"]},
    }
    for ri, row in enumerate(rows):
        rid = "ROW-%d" % (ri + 1)
        position["GRID_ID"]["children"].append(rid)
        position[rid] = {"type": "ROW", "id": rid, "children": [],
                         "parents": ["ROOT_ID", "GRID_ID"],
                         "meta": {"background": "BACKGROUND_TRANSPARENT"}}
        for ci, cid in enumerate(row):
            key = "CHART-%d" % cid
            position[rid]["children"].append(key)
            position[key] = {
                "type": "CHART", "id": key, "children": [],
                "parents": ["ROOT_ID", "GRID_ID", rid],
                "meta": {"chartId": cid, "width": 4, "height": 50,
                         "sliceName": names[cids.index(cid)]},
            }

    body = {
        "dashboard_title": DASH_TITLE,
        "slug": DASH_SLUG,
        "published": True,
        "position_json": json.dumps(position, ensure_ascii=False),
        "json_metadata": json.dumps({"chart_configuration": {}, "color_scheme": "supersetColors"}),
    }

    r = s.get(API + "/dashboard/?q=(page_size:100)", timeout=30)
    have = {d["dashboard_title"]: d.get("id") for d in r.json().get("result", [])}
    if DASH_TITLE in have:
        did = have[DASH_TITLE]
        print("[OK] 复用看板 id=%s，更新布局" % did)
        show(s, "PUT", "/dashboard/%s" % did, data=json.dumps(body))
    else:
        r = show(s, "POST", "/dashboard/", data=json.dumps(body))
        did = r.json().get("id") if r.status_code < 400 else None
        print("[OK] 新建看板 id=%s" % did)
    print("DASHBOARD_ID=%s" % did)
    print("打开地址: http://192.168.150.102:8088/superset/dashboard/%s/" % DASH_SLUG)
    return did


def web_login():
    """网页路由（/superset/explore_json/）需要 session cookie，不能用 JWT"""
    import re
    s = requests.Session()
    r = s.get(BASE + "/login/", timeout=30)
    m = re.search(r'name="csrf_token"[^>]*value="([^"]+)"', r.text)
    if not m:
        raise SystemExit("登录页没找到 csrf_token")
    s.post(BASE + "/login/", data={
        "username": USER, "password": PWD, "csrf_token": m.group(1)},
        allow_redirects=True, timeout=30)
    s.headers.update({"Referer": BASE + "/"})
    return s


def verify_charts(s=None):
    """用网页会话跑一次 explore_json，确认图表能查出数据"""
    ws = web_login()
    r = ws.get(API + "/chart/?q=(page_size:100)", timeout=30)
    ok, bad = 0, []
    for c in r.json().get("result", []):
        params = json.loads(c.get("params") or "{}")
        form = dict(params)
        form["slice_id"] = c["id"]
        rr = ws.post(BASE + "/superset/explore_json/",
                     data={"form_data": json.dumps(form, ensure_ascii=False)},
                     timeout=180)
        if rr.status_code >= 400:
            bad.append((c["slice_name"], "HTTP %s %s" % (rr.status_code, rr.text[:80])))
            continue
        try:
            js = rr.json()
        except Exception:
            bad.append((c["slice_name"], "非 JSON: %s" % rr.text[:80]))
            continue
        if js.get("errors"):
            bad.append((c["slice_name"], str(js["errors"])[:150]))
            continue
        data = js.get("data")
        rows = data.get("data") if isinstance(data, dict) else data
        n = len(rows or [])
        if n == 0:
            bad.append((c["slice_name"], "返回 0 行"))
        else:
            print("[OK] %-30s 返回 %d 行，样例=%s" % (
                c["slice_name"], n, json.dumps(rows[0], ensure_ascii=False)[:110]))
            ok += 1
    print("\n图表可用: %d / %d" % (ok, ok + len(bad)))
    for name, err in bad:
        print("  [FAIL] %-28s %s" % (name, err))
    return ok, bad


def debug_chart(s, chart_id=1):
    r = s.get(API + "/chart/%d" % chart_id, timeout=30)
    c = r.json().get("result", {})
    print("图表:", c.get("slice_name"), "viz:", c.get("viz_type"))
    params = json.loads(c.get("params") or "{}")
    form = dict(params)
    form["slice_id"] = chart_id
    rr = s.post(BASE + "/superset/explore_json/",
                data={"form_data": json.dumps(form, ensure_ascii=False)}, timeout=120)
    print("HTTP:", rr.status_code)
    print("原始返回前 900 字符:")
    print(rr.text[:900])


ADHOC_UV = {
    "expressionType": "SIMPLE",
    "column": {"column_name": "uv", "type": "BIGINT"},
    "aggregate": "SUM",
    "label": "9 天 UV 合计",
    "hasCustomLabel": True,
    "optionName": "metric_uv_sum",
}


def step_fix(s):
    """Superset 6 要求指标显式定义：把大数字卡改成 adhoc metric"""
    r = s.get(API + "/chart/1", timeout=30)
    c = r.json().get("result", {})
    params = json.loads(c.get("params") or "{}")
    ds = params.get("datasource")
    new_params = {
        "datasource": ds,
        "viz_type": "big_number_total",
        "metric": ADHOC_UV,
        "adhoc_filters": [],
        "header_font_size": 0.4,
        "subheader_font_size": 0.15,
        "y_axis_format": "SMART_NUMBER",
    }
    r = show(s, "PUT", "/chart/1", data=json.dumps({
        "slice_name": c.get("slice_name"),
        "viz_type": "big_number_total",
        "datasource_id": c.get("datasource_id"),
        "datasource_type": c.get("datasource_type"),
        "params": json.dumps(new_params, ensure_ascii=False),
    }))
    return r.status_code < 400


def verify2(s):
    """用现代接口 /chart/data 逐张跑，确认能取到数据"""
    r = s.get(API + "/chart/?q=(page_size:100)", timeout=30)
    ok, bad = 0, []
    for c in r.json().get("result", []):
        params = json.loads(c.get("params") or "{}")
        ds_id = c["datasource_id"]
        if params.get("query_mode") == "raw":
            q = {"columns": params.get("all_columns", []), "metrics": [],
                 "row_limit": params.get("row_limit", 100)}
            if params.get("order_by_cols"):
                try:
                    q["orderby"] = [json.loads(x) for x in params["order_by_cols"]]
                except Exception:
                    pass
        else:
            q = {"columns": [], "metrics": [params.get("metric")], "row_limit": 10}
        body = {"datasource": {"id": ds_id, "type": "table"}, "force": False,
                "queries": [q], "result_format": "json", "result_type": "full"}
        rr = s.post(API + "/chart/data", json=body, timeout=180)
        if rr.status_code >= 400:
            bad.append((c["slice_name"], "HTTP %s %s" % (rr.status_code, rr.text[:100])))
            continue
        res = (rr.json().get("result") or [{}])[0]
        if res.get("status") != "success":
            bad.append((c["slice_name"], str(res.get("error"))[:120]))
            continue
        print("[OK] %-30s rowcount=%s" % (c["slice_name"], res.get("rowcount")))
        ok += 1
    print("\n图表可用: %d / %d" % (ok, ok + len(bad)))
    for n, e in bad:
        print("  [FAIL] %-28s %s" % (n, e))
    return ok, bad


def main():
    s = login()
    print("[OK] 登录成功")
    cmd = sys.argv[1] if len(sys.argv) > 1 else "step1"
    if cmd == "step1":
        step1(s)
    elif cmd == "step2":
        step2(s)
    elif cmd == "step3":
        step3(s)
    elif cmd == "fix":
        step_fix(s)
    elif cmd == "verify":
        verify_charts(s)
    elif cmd == "verify2":
        verify2(s)
    elif cmd == "debug":
        debug_chart(s, int(sys.argv[2]) if len(sys.argv) > 2 else 1)
    else:
        print("用法: step1 | step2 | step3 | fix | verify | verify2 | debug <chart_id>")


if __name__ == "__main__":
    main()
