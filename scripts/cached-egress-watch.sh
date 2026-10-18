#!/bin/zsh
# launchd가 매시간 호출. 402 감지(ALERT) 또는 스크립트 자체 실패 시 macOS 알림을 띄운다.
cd "$(dirname "$0")/.."

OUTPUT=$(node scripts/check-cached-egress-block.mjs 70 2>&1)
CODE=$?

if [ $CODE -eq 2 ]; then
  osascript -e "display notification \"$OUTPUT\" with title \"FlyMate prod 장애 감지\" sound name \"Basso\""
elif [ $CODE -ne 0 ]; then
  osascript -e "display notification \"체크 스크립트 실패: $OUTPUT\" with title \"FlyMate Cached Egress 체크 오류\" sound name \"Basso\""
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') exit=$CODE $OUTPUT" >> /tmp/flymate-cached-egress-watch.log
