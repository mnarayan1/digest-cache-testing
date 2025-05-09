Scripts to test caching digest requests with cassandra.

- Install [ccm](https://github.com/apache/cassandra-ccm) locally.
- Clone [modified cassandra source code](https://github.com/mnarayan1/cassandra/tree/digest_cache)

```
./setup_cluster.sh
```

Create baseline and modified build of Cassandra with ccm (update path to Cassandra source code)

```
./test.sh [cassandra_baseline OR cassandra_digest]
```
Run iostat, latency, and tracing tests on both implementations