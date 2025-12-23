#!/usr/bin/env bash

set -e

# Delete kind cluster
kind delete cluster

# Stop and remove all Docker containers (cross-platform way)
echo "Stopping and removing all Docker containers..."
docker ps -aq | xargs -r docker rm -f 2>/dev/null || docker ps -aq | xargs docker rm -f 2>/dev/null || echo "No containers to remove"

# Clean up Docker system
echo "Cleaning up Docker system..."
docker system prune -a -f --volumes
