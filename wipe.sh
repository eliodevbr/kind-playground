#!/usr/bin/env bash

set -e

# Delete kind cluster
kind delete cluster

# Stop and remove all Docker containers (cross-platform way)
echo "Stopping and removing all Docker containers..."
CONTAINERS=$(docker ps -aq)
if [ -n "$CONTAINERS" ]; then
  echo "$CONTAINERS" | xargs -r docker rm -f 2>/dev/null || echo "$CONTAINERS" | xargs docker rm -f 2>/dev/null || echo "Failed to remove some containers"
else
  echo "No containers to remove"
fi

# Clean up Docker system
echo "Cleaning up Docker system..."
docker system prune -a -f --volumes
