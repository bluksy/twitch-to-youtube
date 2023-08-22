#!/bin/sh

set -o allexport
. .env
set +o allexport

if [ -z "$STREAMER_NAME" ]; then
  echo "STREAMER_NAME variable missing"
  exit 1
fi

RETRY_TIME=${RETRY_TIME:-30s}
DESCRIPTION=${DESCRIPTION:""}

echo "Streamer name: $STREAMER_NAME"
echo "Retry time: $RETRY_TIME"
echo "Description: $DESCRIPTION"

if [ -n "$TIMEZONE" ]; then
  export TZ=${TIMEZONE}
  echo "Timezone: $TZ"
fi

while true; do
  TITLE=$(streamlink twitch.tv/"$STREAMER_NAME" -j | jq '.metadata?.title?')

  # Check if streamer is live
  if [ "$TITLE" != null ]; then
    echo "$STREAMER_NAME is live"
    # Remove outer quotes from the title
    TITLE=${TITLE:1:-1}
  else
    if [ "$(date +%M)" = "00" ]; then
      echo "$STREAMER_NAME is not live at $(date)"
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
    -filename - >/dev/null 2>&1

  ./schedule_latest_video.sh
  echo "Recording and uploading completed"
done
