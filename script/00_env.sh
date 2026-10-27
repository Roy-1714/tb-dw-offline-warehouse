#!/bin/bash
# ============================================================
# 00_env.sh  公共环境与执行封装（所有节点脚本 source 它）
#
# 说明：DolphinScheduler 用 `sudo -u atguigu sh cmd` 执行任务，不会加载 .bashrc，
#      所以这里把所有依赖的 HOME/PATH 显式声明，脚本不依赖外部 shell 环境。
# ============================================================
export JAVA_HOME=/opt/module/jdk1.8.0_212
export HADOOP_HOME=/opt/module/hadoop-3.3.4
export HIVE_HOME=/opt/module/hive-3.1.3
export SPARK_HOME=/opt/module/spark-3.3.1-hadoop3
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export PATH=$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HIVE_HOME/bin:$SPARK_HOME/bin:$PATH

export HIVE_METASTORE_URI=thrift://hadoop102:9083
export SPARK_YARN_ARCHIVE=hdfs://hadoop102:8020/spark-archive/spark-3.3.1-hadoop3.jar

PROJECT_HOME=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export PROJECT_HOME
SQL_DIR=$PROJECT_HOME/sql
LOG_DIR=$PROJECT_HOME/logs
mkdir -p "$LOG_DIR"

# 小集群上 Hive Metastore 会被内存压力打掉，这里做自愈：
# 每次执行 SQL 前探测 9083，不通就自动拉起并等待就绪
ensure_metastore() {
  if (echo > /dev/tcp/127.0.0.1/9083) 2>/dev/null; then
    return 0
  fi
  echo "[$(date '+%F %T')] Metastore 未监听，尝试自动拉起"
  nohup setsid "$HIVE_HOME/bin/hive" --service metastore \
    > "$LOG_DIR/metastore_$(date +%H%M%S).log" 2>&1 < /dev/null &
  for _ in $(seq 1 24); do
    sleep 5
    if (echo > /dev/tcp/127.0.0.1/9083) 2>/dev/null; then
      echo "[$(date '+%F %T')] Metastore 已恢复"
      return 0
    fi
  done
  echo "[$(date '+%F %T')] Metastore 启动失败，请手工检查" >&2
  return 1
}

# run_sql <sql文件> [额外 spark-sql 参数...]
run_sql() {
  local f="$1"
  shift
  local name
  name=$(basename "$f" .sql)
  ensure_metastore || return 1
  echo "[$(date '+%F %T')] >>> RUN $name $*"
  spark-sql \
    --master yarn \
    --name "tb_dw_${name}" \
    --conf spark.yarn.archive="${SPARK_YARN_ARCHIVE}" \
    --conf spark.hadoop.hive.metastore.uris="${HIVE_METASTORE_URI}" \
    --conf spark.sql.warehouse.dir=/warehouse/tb_dw \
    --conf spark.sql.session.timeZone=Asia/Shanghai \
    --conf spark.sql.sources.partitionOverwriteMode=dynamic \
    --conf spark.sql.shuffle.partitions=30 \
    --conf spark.hadoop.hive.exec.dynamic.partition.mode=nonstrict \
    --conf spark.sql.adaptive.enabled=true \
    --conf spark.sql.adaptive.skewJoin.enabled=true \
    --conf spark.sql.adaptive.coalescePartitions.enabled=true \
    --conf spark.sql.orc.compression.codec=snappy \
    --conf spark.driver.memory=1536m \
    --conf spark.executor.memory=1g \
    --conf spark.executor.memoryOverhead=384m \
    --conf spark.executor.cores=2 \
    --conf spark.executor.instances=2 \
    --conf spark.dynamicAllocation.enabled=false \
    --conf spark.yarn.maxAppAttempts=1 \
    --conf spark.network.timeout=600s \
    --conf spark.rpc.askTimeout=600s \
    "$@" -f "$f"
  local rc=$?
  echo "[$(date '+%F %T')] <<< DONE $name rc=$rc"
  return $rc
}

# run_sql_date <sql文件> <日期> [额外 spark-sql 参数...]
# 把 SQL 里的 @DO_DATE@ 渲染成具体日期，避免依赖 spark-sql 的变量替换
run_sql_date() {
  local f="$1"
  local d="$2"
  shift 2
  local tmp="$LOG_DIR/$(basename "$f" .sql)_$d.sql"
  sed "s/@DO_DATE@/$d/g" "$f" > "$tmp"
  run_sql "$tmp" "$@"
}
