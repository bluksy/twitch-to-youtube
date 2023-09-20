#!/bin/sh

set -eao pipefail
. .env
set +a

. "$(dirname "$0")/functions.sh"
. "$(dirname "$0")/twitch_api.sh"

OLD_STREAM_TITLE=""
START_IN_SECONDS=$(date +%s)
printf '%s\\n' "Title changes:" > description

while [ ! -f ./collect_stream_info.lock ]
do
  get_stream_detail body status

  if [ "$status" = "200" ]; then
    STREAM_TITLE="$(echo "$body" | jq '.data[0].title')"

    if [ "$STREAM_TITLE" = "null" ]; then
      log "stream ended"
      exit 0
    fi

    if [ "$STREAM_TITLE" != "$OLD_STREAM_TITLE" ]; then
      if [ "$OLD_STREAM_TITLE" = "" ]; then
        TIMESTAMP="00:00:00"
      else
        CURRENT_IN_SECONDS=$(date +%s)
        DIFFSEC=$(expr ${CURRENT_IN_SECONDS} - ${START_IN_SECONDS})
        TIMESTAMP=$(date +%H:%M:%S -ud @"${DIFFSEC}")
      fi

      log "Refreshing title"
      printf '%s %s\\n' "${TIMESTAMP}" "${STREAM_TITLE:1:-1}" >> ./description

      OLD_STREAM_TITLE="$STREAM_TITLE"
    fi

    sleep 1m
    continue
  else
    log "$(echo "$body" | jq '.')"
    touch ./collect_stream_info.lock
    exit 1
  fi
done

log "process is locked"
exit 0