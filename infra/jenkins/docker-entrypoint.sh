#!/usr/bin/env bash
set -euo pipefail

SOCKET_PATH=${DOCKER_SOCKET:-/var/run/docker.sock}

if [ -S "$SOCKET_PATH" ]; then
  if command -v stat >/dev/null 2>&1; then
    if stat --version >/dev/null 2>&1; then
      DOCKER_GID=$(stat -c '%g' "$SOCKET_PATH" || true)
    else
      DOCKER_GID=$(stat -f '%g' "$SOCKET_PATH" || true)
    fi
    if [ -n "${DOCKER_GID:-}" ]; then
      if ! getent group "$DOCKER_GID" >/dev/null 2>&1; then
        groupadd -g "$DOCKER_GID" hostdocker || true
        TARGET_GROUP=hostdocker
      else
        TARGET_GROUP=$(getent group "$DOCKER_GID" | cut -d: -f1)
      fi
      usermod -aG "$TARGET_GROUP" jenkins || true
    fi
  fi
fi

exec "$@"
