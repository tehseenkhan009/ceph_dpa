#!/bin/bash

# Wait for Ceph to be ready script
set -e

host="$1"
port="$2"
shift 2
cmd="$@"

until nc -z "$host" "$port"; do
  >&2 echo "Ceph S3 Gateway is unavailable at $host:$port - sleeping"
  sleep 1
done

>&2 echo "Ceph S3 Gateway is up at $host:$port - executing command"
exec $cmd