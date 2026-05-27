#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "錯誤：找不到 ${ENV_FILE}"
  echo "請先複製 .env.example 為 .env 並填入參數。"
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

if [[ -z "${RCLONE_REMOTE:-}" && -n "${RCLONE_TARGET:-}" ]]; then
  echo "警告：偵測到舊參數 RCLONE_TARGET，建議改用 RCLONE_REMOTE。"
  RCLONE_REMOTE="${RCLONE_TARGET}"
fi

for key in RCLONE_REMOTE RCLONE_REMOTE_SUBDIR LOCAL_SYNC_DIR; do
  if [[ -z "${!key:-}" ]]; then
    echo "錯誤：${key} 尚未設定（${ENV_FILE}）"
    exit 1
  fi
done

for cmd in rclone rsync; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "錯誤：找不到 ${cmd}，請先安裝。"
    exit 1
  fi
done

if [[ "${RCLONE_REMOTE}" == *:* ]]; then
  RCLONE_REMOTE_SPEC="${RCLONE_REMOTE}"
else
  RCLONE_REMOTE_SPEC="${RCLONE_REMOTE}:"
fi

MOUNT_DIR="$(mktemp -d)"
RSYNC_SOURCE="${MOUNT_DIR}/${RCLONE_REMOTE_SUBDIR%/}/"
RSYNC_TARGET="${LOCAL_SYNC_DIR%/}/"
RCLONE_PID=""

cleanup() {
  set +e
  if mountpoint -q "${MOUNT_DIR}" 2>/dev/null; then
    if command -v fusermount >/dev/null 2>&1; then
      fusermount -u "${MOUNT_DIR}" >/dev/null 2>&1 || true
    else
      umount "${MOUNT_DIR}" >/dev/null 2>&1 || true
    fi
  fi

  if [[ -n "${RCLONE_PID}" ]] && kill -0 "${RCLONE_PID}" 2>/dev/null; then
    kill "${RCLONE_PID}" >/dev/null 2>&1 || true
  fi

  rm -rf "${MOUNT_DIR}"
}
trap cleanup EXIT

echo "==> 掛載 remote ${RCLONE_REMOTE_SPEC} 至 ${MOUNT_DIR}"
rclone mount "${RCLONE_REMOTE_SPEC}" "${MOUNT_DIR}" --vfs-cache-mode writes &
RCLONE_PID=$!

for _ in {1..30}; do
  if mountpoint -q "${MOUNT_DIR}" 2>/dev/null; then
    break
  fi
  sleep 1
done

if ! mountpoint -q "${MOUNT_DIR}" 2>/dev/null; then
  echo "錯誤：rclone mount 逾時，無法完成掛載。"
  exit 1
fi

if [[ ! -d "${RSYNC_SOURCE}" ]]; then
  echo "錯誤：來源資料夾不存在：${RSYNC_SOURCE}"
  exit 1
fi

if [[ ! -d "${RSYNC_TARGET}" ]]; then
  echo "錯誤：本機同步目錄不存在：${RSYNC_TARGET}"
  exit 1
fi

echo "==> 開始同步"
if [[ -n "${EXCLUDE_PREFIX:-}" ]]; then
  rsync -avh --delete --info=progress2 \
    --exclude "${EXCLUDE_PREFIX}*" \
    "${RSYNC_SOURCE}" "${RSYNC_TARGET}"
else
  rsync -avh --delete --info=progress2 \
    "${RSYNC_SOURCE}" "${RSYNC_TARGET}"
fi

echo "同步完成。"