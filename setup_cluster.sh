#!/bin/bash
set -euo pipefail

CASSANDRA_BASELINE_VERSION="4.1.2"
CASSANDRA_DIGEST_PATH=""

BASELINE_CLUSTER="cassandra_baseline"
DIGEST_CLUSTER="cassandra_digest"

NODES=3

echo "Creating baseline cluster (${BASELINE_CLUSTER}) using Cassandra ${CASSANDRA_BASELINE_VERSION}"
ccm remove $BASELINE_CLUSTER || true
ccm create $BASELINE_CLUSTER -v $CASSANDRA_BASELINE_VERSION -n $NODES -s
echo "Baseline cluster started."

echo "Creating digest cluster (${DIGEST_CLUSTER}) using custom build at $CASSANDRA_DIGEST_PATH"
ccm remove $DIGEST_CLUSTER || true
ccm create $DIGEST_CLUSTER --install-dir=$CASSANDRA_DIGEST_PATH -n $NODES -s
echo "Digest cluster started."

echo ""
echo "All clusters set up and running:"
ccm list