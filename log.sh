#!/bin/bash
# ════════════════════════════════════════════════
#  宠联芯 实时日志查看器
#  用法：./log.sh [--full] [--clear] [--request ID] [--level warning]
#    --video 只看视频链路；--stream ID 只看某次观看；--dump 读取历史后退出
#    --module 名称  按模块筛选；--since '10-21 10:00:00.000' 从指定时间读取
# ════════════════════════════════════════════════

ADB=~/Library/Android/sdk/platform-tools/adb
PKG="com.junxin.petpogo_and"
FULL_MODE=false
CLEAR_HISTORY=false
DUMP_MODE=false
STREAM_FILTER=""
REQUEST_FILTER=""
LEVEL_FILTER=""
MODULE_FILTER=""
SINCE_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full) FULL_MODE=true; shift ;;
    --clear) CLEAR_HISTORY=true; shift ;;
    --video) MODULE_FILTER="device.stream."; shift ;;
    --dump) DUMP_MODE=true; shift ;;
    --request|--level|--module|--since|--stream)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "❌ $1 需要一个参数"; exit 1
      fi
      case "$1" in
        --request) REQUEST_FILTER="$2" ;;
        --stream) STREAM_FILTER="$2" ;;
        --level) LEVEL_FILTER="$2" ;;
        --module) MODULE_FILTER="$2" ;;
        --since) SINCE_FILTER="$2" ;;
      esac
      shift 2 ;;
    --help|-h)
      echo "用法：./log.sh [--full] [--clear] [--request ID] [--level warning|error|info] [--module 名称] [--since 时间] [--video] [--stream ID] [--dump]"
      echo "视频实时日志：./log.sh --video；历史快照：./log.sh --video --dump"
      exit 0 ;;
    *) echo "❌ 未知参数：$1"; exit 1 ;;
  esac
done

# 先找真机（非 emulator 开头的在线设备）
DEVICE=$($ADB devices | grep -v "^List" | grep "device$" | grep -v "emulator" | head -1 | awk '{print $1}')

if [ -n "$DEVICE" ]; then
  echo "  ✅ 找到真机: $DEVICE"
else
  # 真机没有，找模拟器
  DEVICE=$($ADB devices | grep -E "emulator-[0-9]+" | grep "device$" | head -1 | awk '{print $1}')
fi

if [ -z "$DEVICE" ]; then
  echo "❌ 没有找到任何设备（真机或模拟器），请先连接设备或运行 ./run.sh"
  exit 1
fi

# 获取 App 进程 PID
PID=$($ADB -s $DEVICE shell pidof -s $PKG 2>/dev/null | tr -d '\r')

if [ -z "$PID" ]; then
  echo "❌ App 未运行，请先启动 App"
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       宠联芯 实时日志                    ║"
echo "╚══════════════════════════════════════════╝"
echo "📱 设备: $DEVICE   PID: $PID"
echo "🎨 绿=成功  红=错误  青=网络  紫=页面  黄=状态"
if $FULL_MODE; then
  echo "📋 模式: 完整（所有 tag）"
else
  echo "📋 模式: Flutter 日志（./log.sh --full 显示全部）"
fi
echo "────────────────────────────────────────────"
echo ""

# 加大 logcat 环形缓冲区至 16MB，减少高频日志被挤掉
$ADB -s $DEVICE logcat -G 16M 2>/dev/null || true

# Preserve history by default. Only explicitly clear it when requested.
if $CLEAR_HISTORY; then
  $ADB -s $DEVICE logcat -c
fi

colorize() {
  while IFS= read -r line; do
    [[ -n "$STREAM_FILTER" && "$line" != *"\"streamId\":\"$STREAM_FILTER\""* ]] && continue
    [[ -n "$REQUEST_FILTER" && "$line" != *"$REQUEST_FILTER"* ]] && continue
    [[ -n "$LEVEL_FILTER" && "$line" != *"\"level\":\"$LEVEL_FILTER\""* ]] && continue
    [[ -n "$MODULE_FILTER" && "$line" != *"$MODULE_FILTER"* ]] && continue
    if [[ "$line" == *'"level":"warning"'* || "$line" == *'"level":"error"'* ]]; then
      echo -e "\033[31m$line\033[0m"
    elif echo "$line" | grep -qE "✅|成功|loggedIn|\[API 响应\]"; then
      echo -e "\033[32m$line\033[0m"
    elif echo "$line" | grep -qE "✗|失败|[Ee]rror|[Ee]xception|\[API 错误\]"; then
      echo -e "\033[31m$line\033[0m"
    elif echo "$line" | grep -qE "→ POST|→ GET|\[API 请求\]|│ Body:|│ Headers:|│ Query:|│ Status:"; then
      echo -e "\033[36m$line\033[0m"
    elif echo "$line" | grep -qE "\[路由\]"; then
      echo -e "\033[35m$line\033[0m"
    elif echo "$line" | grep -qE "\[状态\]"; then
      echo -e "\033[33m$line\033[0m"
    else
      echo "$line"
    fi
  done
}

LOG_ARGS=(--pid="$PID")
if $DUMP_MODE; then
  LOG_ARGS+=(-d)
fi
if [[ -n "$SINCE_FILTER" ]]; then
  LOG_ARGS+=(-T "$SINCE_FILTER")
fi
if $FULL_MODE; then
  # 完整模式：App PID 的所有 tag
  "$ADB" -s "$DEVICE" logcat "${LOG_ARGS[@]}" 2>&1 | colorize
else
  # 默认模式：只看 flutter tag（直接 logcat tag 过滤）
  "$ADB" -s "$DEVICE" logcat "${LOG_ARGS[@]}" flutter:V "*:S" 2>&1 | colorize
fi
