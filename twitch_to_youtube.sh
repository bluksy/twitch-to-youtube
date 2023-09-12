#!/bin/sh

if [ -f ./twitch_to_youtube.lock ]; then
  echo process is locked
  exit 0
fi

set -eao pipefail
. .env
set +a

. "$(dirname "$0")/functions.sh"

if [ -z "$STREAMER_NAME" ]; then
  log "STREAMER_NAME variable missing"
  touch ./twitch_to_youtube.lock
  exit 1
fi

if [ -n "$TIMEZONE" ]; then
  export TZ=${TIMEZONE}
  log "Timezone: $TZ"
fi

RETRY_TIME=${RETRY_TIME:-30s}
DESCRIPTION=${DESCRIPTION:""}

log "Streamer name: $STREAMER_NAME"
log "Retry time: $RETRY_TIME"
log "Description: $DESCRIPTION"

while [ ! -f ./twitch_to_youtube.lock ]; do
  TITLE=$(streamlink twitch.tv/"$STREAMER_NAME" -j | jq '.metadata?.title?' || true)
  TITLE=${TITLE:-null}

  # Check if streamer is live
  if [ "$TITLE" != null ]; then
    log "$STREAMER_NAME is live"
    # Remove outer quotes from the title
    TITLE=${TITLE:1:-1}
  else
    if [ "$(date +%M)" = "00" ]; then
      log "$STREAMER_NAME is not live"
    fi

    sleep "$RETRY_TIME"
    continue
  fi

  TIMEDATE=$(date +%F)

  # Create the input file containing upload parameters
  printf '{
    "title": "%s | %s | %s",
    "privacyStatus": "private",
    "recordingDate": "%s",
    "description": "%s"
  }' "${STREAMER_NAME}" "${TIMEDATE}" "${TITLE}" "${TIMEDATE}" "${DESCRIPTION}" > ./yt_input

  # Limit the stream duration to 10 hours for YouTube
  streamlink twitch.tv/$STREAMER_NAME best \
    --hls-duration 10:00:00 \
    --twitch-disable-hosting \
    --config ./auth/config.twitch \
    -O 2>/dev/null | ./youtubeuploader/youtubeuploader \
    -cache ./auth/request.token \
    -secrets ./auth/yt_secrets.json \
    -metaJSON ./yt_input \
    -filename - >/dev/null 2>&1 || (touch ./twitch_to_youtube.lock && exit 1)

  ./schedule_latest_video.sh || (touch ./twitch_to_youtube.lock && exit 1)
  log "Recording and uploading completed"
done
