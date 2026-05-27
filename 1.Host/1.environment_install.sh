#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../2.Drive/.env"

echo "==> 檢查必要指令"
for cmd in rclone rsync; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "錯誤：找不到 ${cmd}，請先安裝後再重試。"
    exit 1
  fi
  echo "  - ${cmd}: $(command -v "${cmd}")"
done

echo
echo "==> 檢查設定檔"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "錯誤：找不到設定檔 ${ENV_FILE}"
  echo "請先複製 ../2.Drive/.env.example 為 ../2.Drive/.env 並填入參數。"
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

if [[ -z "${RCLONE_REMOTE:-}" && -n "${RCLONE_TARGET:-}" ]]; then
  echo "警告：偵測到舊參數 RCLONE_TARGET，建議改用 RCLONE_REMOTE。"
  RCLONE_REMOTE="${RCLONE_TARGET}"
fi

missing=0
for key in RCLONE_REMOTE RCLONE_REMOTE_SUBDIR LOCAL_SYNC_DIR; do
  if [[ -z "${!key:-}" ]]; then
    echo "錯誤：${key} 尚未設定（${ENV_FILE}）"
    missing=1
  fi
done

if [[ "${missing}" -ne 0 ]]; then
  exit 1
fi

if [[ "${RCLONE_REMOTE}" == *:* ]]; then
  RCLONE_REMOTE_NAME="${RCLONE_REMOTE%%:*}"
  RCLONE_REMOTE_SPEC="${RCLONE_REMOTE}"
else
  RCLONE_REMOTE_NAME="${RCLONE_REMOTE}"
  RCLONE_REMOTE_SPEC="${RCLONE_REMOTE}:"
fi

echo
echo "==> 檢查 rclone remote"
if ! rclone listremotes | sed 's/:$//' | rg -Fx -- "${RCLONE_REMOTE_NAME}" >/dev/null 2>&1; then
  echo "找不到 rclone remote: ${RCLONE_REMOTE_NAME}"
  echo "現在開啟 rclone config，請依指示完成設定。"
  rclone config

  if ! rclone listremotes | sed 's/:$//' | rg -Fx -- "${RCLONE_REMOTE_NAME}" >/dev/null 2>&1; then
    echo "錯誤：設定後仍找不到 remote ${RCLONE_REMOTE_NAME}"
    echo "請確認 .env 的 RCLONE_REMOTE 是否正確。"
    exit 1
  fi
fi

echo "rclone remote 檢查通過：${RCLONE_REMOTE_NAME}（掛載格式：${RCLONE_REMOTE_SPEC}）"
echo "設定檢查通過。"
echo "你可以繼續執行 ../2.Drive/drive-update.sh"

