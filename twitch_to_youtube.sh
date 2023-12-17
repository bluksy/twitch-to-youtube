#!/bin/ash

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

_retry_time=${RETRY_TIME:-30s}
_description=${DESCRIPTION:-""}
_max_length=${MAX_LENGTH:-"8:00:00"}

log "Streamer name: $STREAMER_NAME"
log "Retry time: $_retry_time"
log "Description: $_description"
log "Max length: $_max_length"

while [ ! -f ./twitch_to_youtube.lock ]; do
  _stream_title=$(streamlink twitch.tv/"$STREAMER_NAME" -j | jq '.metadata?.title?' || true)
  _stream_title=${_stream_title:-null}

  # Check if streamer is live
  if [ "$_stream_title" != null ]; then
    log "$STREAMER_NAME is live"
    # Remove outer quotes from the title
    _stream_title=${_stream_title:1:-1}
  else
    if [ "$(date +%M)" = "00" ]; then
      log "$STREAMER_NAME is not live"
    fi

    sleep "$_retry_time"
    continue
  fi

  ./collect_stream_info.sh &
  _current_timedate=$(date +%F)

  # Create the input file containing upload parameters
  printf '{
    "title": "%s | %s | %s",
    "privacyStatus": "private",
    "recordingDate": "%s",
    "description": "%s"
  }' "${STREAMER_NAME}" "${_current_timedate}" "${_stream_title}" "${_current_timedate}" "${_description}" > ./yt_input

  streamlink twitch.tv/$STREAMER_NAME best \
    --hls-duration $_max_length \
    --twitch-disable-hosting \
    --config ./auth/config.twitch \
    -O 2>/dev/null | ./youtubeuploader/youtubeuploader \
    -cache ./auth/request.token \
    -secrets ./auth/yt_secrets.json \
    -metaJSON ./yt_input \
    -filename - >/dev/null 2>&1 || (touch ./twitch_to_youtube.lock && exit 1)

  ./update_latest_video.sh || (touch ./twitch_to_youtube.lock && exit 1)
  log "Recording and uploading completed"
done
