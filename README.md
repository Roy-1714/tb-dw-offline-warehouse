# tb_dw —— 淘宝用户行为离线数仓

基于 **1 亿行真实电商行为埋点**（淘宝 UserBehavior）从零搭建的离线数仓：ODS → DIM → DWD → DWS → ADS 五层、20 张表、10 节点 DolphinScheduler 调度，计算引擎为 Spark SQL on YARN。

> 数据源：`UserBehavior.csv`，100,150,807 行 / 3.5 GB / 987,994 用户 / 4,162,024 商品 / 9 天（2017-11-25 ~ 2017-12-03）

## 这个项目解决什么问题

单张行为明细表，没有订单金额、没有用户/商品维表、没有渠道信息。所以项目要回答的是**在这种"薄"数据上能建出多深的数仓**：

- 明细层怎么做清洗、去重、时区对齐（数据里有 5.5 万行越界时间戳、98 万行乱序）
- 没有维表时，维度怎么从事实反推（商品主类目取众数，因为 600 个商品跨类目）
- 1 亿行在 3 节点 7.8G/3.7G 的小集群上怎么跑得动（先减并发、AQE、ORC+snappy）
- 哪些指标**不能做**（无金额 → 不做 GMV/客单价/退款率，只用 R/F 不用 M）

## 架构

```
UserBehavior.csv (3.5G)
      │  HDFS /origin_data/tb_dw/UserBehavior
      ▼
┌─────────────┐   TextFile, 按 dt 分区, 越界进 invalid
│     ODS     │   ods_user_behavior
└─────┬───────┘
      ▼  Spark SQL · 清洗/去重/派生时间
┌─────────────┐   ORC+snappy, 按 dt 增量
│     DWD     │   dwd_user_behavior_detail + dwd_dq_stat
└─────┬───────┘
      ▼  聚合降维
┌─────────────┐   user / item / category 三粒度 + 7 日滚动 + 累计快照
│     DWS     │   dws_user_action_1d / _nd / _td, dws_item_action_1d, dws_category_action_1d
└─────┬───────┘
      ▼
┌─────────────┐   10 张面向分析的指标表
│     ADS     │   DAU / 漏斗 / 留存 / 分时 / TopN / 频次 / RF / 路径 / 集中度
└─────┬───────┘
      ▼  HDFS 文本 → getmerge → LOAD DATA
   MySQL tb_dw_report（供 Superset 直连）
```

维度层：`dim_date`（静态日期维）、`dim_item`（商品主类目 + 跨类目标记）。

## 目录结构

```
offline-dw/
├── README.md
├── docs/
│   ├── 01-数据探查.md      全量画像、行为分布、数据质量问题、能力边界
│   ├── 02-建模设计.md      分层设计、表清单、分区策略、增量策略、DAG
│   ├── 03-指标口径.md      10 张 ADS 表逐项口径与限制
│   └── 04-实施记录.md      真实踩坑与解决（含时区边界 bug、OOM、DS 部署）
├── sql/
│   ├── 00_init.sql         建库 tb_dw
│   ├── 01_ods.sql          原始表 + ODS 分区装载（含 invalid 分流）
│   ├── 02_dim_date.sql     日期维
│   ├── 03_dwd.sql          明细清洗 + 数据质量统计
│   ├── 04_dws_user.sql     用户日粒度
│   ├── 05_dws_item_category.sql  商品/类目日粒度
│   ├── 06_dws_nd_td.sql    滚动 7 日 + 累计快照
│   ├── 07_dim_item.sql     商品维（主类目取众数）
│   ├── 08_ads_core.sql     DAU/漏斗/留存/分时
│   ├── 09_ads_topic.sql    TopN/频次/RF/路径/集中度
│   ├── 10_export.sql       ADS → HDFS 文本
│   ├── mysql_ddl.sql       MySQL 报表库建表
│   └── 90_verify_ods.sql   ODS 验收 SQL
├── script/
│   ├── 00_env.sh           公共环境 + run_sql / run_sql_date
│   ├── 00_backfill.sh      9 天回溯编排
│   ├── 01_ods_load.sh ~  10_export_mysql.sh   10 个调度节点脚本
├── scheduler/
│   └── ds_build_workflow.py 用 DS 2.0.5 API 建 10 节点工作流
└── dashboard/
    └── superset_build.py    用 Superset API 建数据源/数据集/图表/看板
```

## 可视化看板（Superset）

| 项 | 值 |
|---|---|
| 地址 | **http://192.168.150.102:8088** |
| 账号 | `admin` / `admin123` |
| 看板 | 「淘宝用户行为数仓看板」`/superset/dashboard/tb-dw-dashboard/` |
| 数据源 | MySQL `tb_dw_report`（10 张 ADS 镜像表） |
| 图表 | 6 张：总 UV 大数字卡、每日 UV/PV 趋势、行为漏斗、类目 Top10、分时活跃、商品集中度 |

**一键重建**（数据集、图表、看板全用 API 创建，可重复执行）：

```bash
/opt/module/miniconda3/envs/superset/bin/python dashboard/superset_build.py step1    # 数据源 + 10 数据集
/opt/module/miniconda3/envs/superset/bin/python dashboard/superset_build.py step2    # 6 张图表
/opt/module/miniconda3/envs/superset/bin/python dashboard/superset_build.py step3    # 看板 + 布局
/opt/module/miniconda3/envs/superset/bin/python dashboard/superset_build.py verify2  # 逐张验证出数
```

**机器重启后拉起 Superset**：

```bash
cd /opt/module/miniconda3/envs/superset/bin
SUPERSET_CONFIG_PATH=/opt/module/superset/superset_config.py \
  nohup ./superset run -h 0.0.0.0 -p 8088 --with-threads > /opt/module/superset/superset.log 2>&1 &
```

> 两个 Superset 6.1 的坑：
> ① 旧接口 `explore_json` 已不注册 `table`/`big_number_total` 这类可视化，验证图表出数要用 `/api/v1/chart/data`；
> ② 指标必须显式定义，`SUM(uv)` 这种字符串会报 `Metric does not exist`，要用 adhoc metric 对象。

## 环境要求

| 组件 | 版本 | 说明 |
|---|---|---|
| Hadoop | 3.3.4 | HDFS + YARN，3 节点 |
| Hive | 3.1.3 | 仅用 Metastore（thrift://hadoop102:9083） |
| Spark | 3.3.1（bin-hadoop3） | 计算引擎，需带 Hive 支持的发行版 |
| MySQL | 8.0.31 | Metastore / 报表库 |
| DolphinScheduler | 2.0.5 | 调度，ZooKeeper 3.7.1 注册中心 |
| JDK | 1.8.0_212 | |

关键配置（`script/00_env.sh`）：

```bash
export HADOOP_CONF_DIR=/opt/module/hadoop-3.3.4/etc/hadoop
export SPARK_HOME=/opt/module/spark-3.3.1-hadoop3     # 不能用 bin-without-hadoop 版
export SPARK_YARN_ARCHIVE=hdfs://hadoop102:8020/spark-archive/spark-3.3.1-hadoop3.jar
```

Spark 提交固定参数（受小集群内存约束，详见 docs/04）：

```bash
--conf spark.driver.memory=1g --conf spark.executor.memory=1g
--conf spark.executor.instances=2 --conf spark.executor.memoryOverhead=384m
--conf spark.sql.shuffle.partitions=30 --conf spark.sql.adaptive.enabled=true
--conf spark.network.timeout=600s --conf spark.rpc.askTimeout=600s
```

## 运行方式

**方式一：手动逐节点（推荐先跑通）**

```bash
# 1) ODS（原始文件入 HDFS + 分区装载）
bash script/01_ods_load.sh

# 2) 单日链路（do_date 为业务日）
bash script/02_dim_date_init.sh
bash script/03_dwd_detail_1d.sh 2017-12-03
bash script/05_dws_user_1d.sh    2017-12-03
bash script/06_dws_item_category_1d.sh 2017-12-03
bash script/07_dws_nd_td.sh      2017-12-03
bash script/08_ads_core_1d.sh    2017-12-03
bash script/09_ads_topic_1d.sh   2017-12-03
bash script/04_dim_item.sh
bash script/10_export_mysql.sh
```

**方式二：9 天回溯**

```bash
SKIP_ODS=1 bash script/00_backfill.sh
```

> `07_dws_nd_td.sh` 依赖前一日 `dws_user_action_td` 快照，**必须按日期升序执行**。

**方式三：DolphinScheduler 调度**

```bash
python scheduler/ds_build_workflow.py     # 建 10 节点工作流并上线
```

节点之间串行，`do_date` 通过全局参数传入，脚本内部渲染 `@DO_DATE@`。

## 验收口径

| 层 | 验收方法 |
|---|---|
| ODS | 逐日分区行数与 awk 全量画像比对，总量须等于 100,150,807，`invalid` 分区约 55,576 |
| DWD | `dwd_dq_stat` 中 `src_rows - dup_rows == kept_rows`；行为类型分布与 ODS 一致 |
| DWS | 1d 表按 `dt` 汇总的 pv/buy 之和等于 DWD 对应分区行数 |
| ADS | 漏斗 `pv_uv >= cart_uv`、`buy_uv <= cart_uv`；留存率 ∈ [0,1] |
| 导出 | MySQL 各表行数与 HDFS 导出文件行数一致 |

## 已知限制

1. **无金额字段** → 不做 GMV/客单价/退款率/ROI；RF 分层只保留 R、F 两维
2. **只有 9 天数据** → `dt+7` 留存对后几天不可得，报表需标注数据窗口
3. **无 session_id** → 路径分析是"当日行为序列"，不是严格会话路径
4. **漏斗是同天漏斗** → 不跟踪跨天转化
5. **集群内存极小**（103/104 仅 3.7 G）→ 执行器只能开 2 个，吞吐受限；DS 与 Spark 同时跑会 OOM，需错峰

## 运行结果（2026-10-23 实测）

### 各层数据量

| 层 | 表 | 结果 |
|---|---|---|
| ODS | ods_user_behavior | 9 天分区 + `invalid`，总量 **100,150,807**，invalid **55,576** |
| DWD | dwd_user_behavior_detail | 9 天分区，逐日 = ODS − 完全重复行，**去重共 49 行** |
| DWD | dwd_dq_stat | 9 行，`src_rows - dup_rows = kept_rows` 全部成立，非法行为 0 |
| DIM | dim_item | **4,161,138** 商品，其中跨类目 **1,405** |
| DIM | dim_date | 61 天（2017-11-01~12-31），周末 18 天 |
| DWS | dws_user_action_1d / _nd / _td | 各 9 个分区 |
| DWS | dws_item_action_1d / dws_category_action_1d | 各 9 个分区 |
| ADS | 10 张表 | 全部 9 个分区（分时表 216 行、商品 TopN 450 行、类目 TopN 270 行、路径 180 行等） |
| 导出 | MySQL tb_dw_report | 10 张表，行数与 HDFS 导出文件逐表一致 |

### 交叉校验（关键证据）

- **ODS 逐分区** 与 3.5 GB 文件的全量 awk 画像**逐日完全一致**（10,420,015 / 10,664,602 / … / 13,662,159）
- **DWS 与 DWD 对账**：9 天的 `dws_pv`、`dws_buy` 与 DWD 当日 `pv`、`buy` 行数**全部相等**
- **漏斗单调性**：9 天全部满足 `pv_uv ≥ cart_uv ≥ buy_uv`
- 例（2017-11-25）：UV 706,641，PV 9,353,416，购买人数 132,622，浏览→购买转化 19.3%

### 倾斜证据（ads_item_skew_1d）

前 1% 商品贡献 **24.4% ~ 26.4%** 的浏览量，单商品最高约占 0.03%~0.18%。这说明按 `item_id` 聚合确实存在热点，是"要不要加盐/两阶段聚合"的量化依据。

### DolphinScheduler 实际调度结果（实例 8，2026-10-23 22:26:20 → 22:36:39）

| 节点 | 状态 | 耗时 |
|---|---|---|
| 01_ods_load | SUCCESS | 7 s（命中装载标记，跳过 1 亿行重载） |
| 02_dim_date_init | SUCCESS | 55 s |
| 03_dwd_detail_1d | SUCCESS | 2 min 04 s |
| 04_dim_item | SUCCESS | 3 s（命中维表缓存标记） |
| 05_dws_user_1d | SUCCESS | 1 min 22 s |
| 06_dws_item_category_1d | SUCCESS | 1 min 45 s |
| 07_dws_nd_td | SUCCESS | 46 s |
| 08_ads_core_1d | SUCCESS | 44 s |
| 09_ads_topic_1d | SUCCESS | 59 s |
| 10_export_mysql | SUCCESS | 1 min 05 s |

**10/10 节点成功，整条链路 10 分 19 秒**。工作流通过 API 触发（`processDefinitionCode=23465045574688`），参数 `do_date=2017-12-03`。

## 当前状态

已完成并验收：

- 数据全量画像、五层 20 张表建模与 DDL、10 个节点脚本
- ODS → DWD → DIM → DWS → ADS 全链路 9 天跑通，数据量逐层对账通过
- ADS 导出 MySQL 并核对行数（10 张表逐表一致）
- DolphinScheduler 2.0.5（standalone）部署、10 节点工作流创建并上线、**实跑 10/10 节点成功**
- 管线自愈：MetaStore 掉线自动拉起、ODS/维表装载标记避免重复计算

已知待办：

- DS 的 Cron 周期调度与告警渠道未配置（当前为 API/手工触发）
- Superset 看板未接入（MySQL 报表库已就绪，可直接连）
- 集群资源极小（103/104 仅 3.7 G）：Spark 只开 2 个执行器、driver 1.5 G，与 DS 同时运行需错峰

详细踩坑与修复见 `docs/04-实施记录.md`。
