#!/bin/bash
set -euo pipefail

KEYSPACE="testks"
TABLE="users"
NUM_KEYS=10
CLUSTER_NAME="$1"
LOG_DIR="logs_${CLUSTER_NAME}"
IOSTAT_FILE="${LOG_DIR}/iostat.txt"
LATENCY_LOG="${LOG_DIR}/latency.txt"

wait_for_cassandra() {
  echo "Waiting for Cassandra to be ready..."
  for i in {1..30}; do
    if nc -z 127.0.0.1 9042; then
      echo "Cassandra is up."
      return
    fi
    sleep 1
  done
  echo "Timed out waiting for Cassandra."
  exit 1
}

stop_all_clusters() {
  echo "Stopping all clusters..."
  for cluster in $(ccm list | awk '{print $1}'); do
    ccm switch "$cluster" && ccm stop || true
  done
}

inject_row_to_node1() {
  local user_id="$1"
  ccm node1 cqlsh <<EOF
CREATE KEYSPACE IF NOT EXISTS ${KEYSPACE} WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3};
USE ${KEYSPACE};
CREATE TABLE IF NOT EXISTS ${TABLE} (id text PRIMARY KEY, name text, email text);
INSERT INTO ${TABLE} (id, name, email) VALUES ('user${user_id}', 'User ${user_id}', 'user${user_id}@example.com');
EOF
}

if ! ccm list | grep -q "$CLUSTER_NAME"; then
  echo "Cluster '$CLUSTER_NAME' does not exist."
  exit 1
fi

mkdir -p "$LOG_DIR"

stop_all_clusters
ccm switch "$CLUSTER_NAME"
wait_for_cassandra
flush_os_cache

echo "Starting iostat during reads..."
iostat -dxm 1 > "$IOSTAT_FILE" &
IOSTAT_PID=$!

echo "Running $NUM_KEYS reads with fresh inconsistent data..."
> "$LATENCY_LOG"

for i in $(seq 1 $NUM_KEYS); do
  echo "Injecting inconsistent row user$i..."
  inject_row_to_node1 "$i"

  START=$(date +%s%3N)

  TRACE_OUTPUT=$(echo "TRACING ON; CONSISTENCY QUORUM; SELECT * FROM ${KEYSPACE}.${TABLE} WHERE id='user${i}';" | ccm node2 cqlsh)
  END=$(date +%s%3N)
  LATENCY=$((END - START))
  echo "Read user$i: ${LATENCY} ms"
  echo "$LATENCY" >> "$LATENCY_LOG"

  SESSION_ID=$(echo "$TRACE_OUTPUT" | grep "Tracing session:" | awk '{print $3}')
  if [[ -n "$SESSION_ID" ]]; then
    ccm node2 cqlsh -e "SELECT source_elapsed, activity FROM system_traces.events WHERE session_id=$SESSION_ID;" > "${LOG_DIR}/trace_user${i}.log"
  else
    echo "Warning: No tracing session ID found for user$i" >> "${LOG_DIR}/trace_user${i}.log"
  fi
done

echo "Stopping iostat..."
kill $IOSTAT_PID || true

ccm stop

echo ""
echo "Benchmark complete for $CLUSTER_NAME."
echo "Latencies: $LATENCY_LOG"
echo "I/O logs : $IOSTAT_FILE"
echo "Traces   : ${LOG_DIR}/trace_user*.log"