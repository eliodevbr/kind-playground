#!/usr/bin/env bash

set -e

# Delete kind cluster
kind delete cluster

# Stop and remove all Docker containers (cross-platform way)
echo "Stopping and removing all Docker containers..."
CONTAINERS=$(docker ps -aq)
if [ -n "$CONTAINERS" ]; then
  # Try to remove containers one by one to handle both GNU and BSD xargs
  echo "$CONTAINERS" | while read -r container; do
    docker rm -f "$container" 2>/dev/null || true
  done
else
  echo "No containers to remove"
fi

# Clean up Docker system
echo "Cleaning up Docker system..."
docker system prune -a -f --volumes
