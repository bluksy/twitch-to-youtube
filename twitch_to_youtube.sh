#!/bin/ash

set -eao pipefail
. .env
set +a

. "$(dirname "$0")/functions.sh"

if [ -f ./twitch_to_youtube.lock ]; then
  log "process is locked"
  exit 0
fi

if [ -z "$STREAMER_NAME" ]; then
  log "STREAMER_NAME variable missing"
  touch ./twitch_to_youtube.lock
  exit 1
fi

if [ ! -f ./auth/yt_secrets.json ]; then
    log "File ./auth/yt_secrets.json does not exist"
    touch ./twitch_to_youtube.lock
    exit 1
fi

if [ ! -f ./auth/request.token ]; then
    log "File ./auth/request.token does not exist"
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

upload_attempt=0

while [ ! -f ./twitch_to_youtube.lock ] && [ $upload_attempt -lt 10 ]; do
  _stream_title=$(streamlink twitch.tv/"$STREAMER_NAME" -j | jq '.metadata?.title?' || true)
  _stream_title=${_stream_title:-null}

  # Check if streamer is live
  if [ "$_stream_title" != null ]; then
    log "$STREAMER_NAME is live. Upload attempt $upload_attempt"
  else
    if [ "$(date +%M)" = "00" ]; then
      log "$STREAMER_NAME is not live"
    fi

    # reset counter
    upload_attempt=0
    sleep "$_retry_time"
    continue
  fi

  ./collect_stream_info.sh &
  _collect_stream_info_pid=$!
  _current_timedate=$(date +%F)
  # Remove outer quotes from the title
  _stream_title=${_stream_title:1:-1}
  # Cut the title if it's too long for youtube
  _stream_title=$(printf "%s" "${_stream_title}" | cut -c 1-88)
  _youtube_title=$(printf "%s | %s" "${_stream_title}" "${_current_timedate}")

  # Create the input file containing upload parameters
  printf '{
    "title": "%s",
    "privacyStatus": "private",
    "recordingDate": "%s",
    "description": "%s"
  }' "${_youtube_title}" "${_current_timedate}" "${_description}" > ./yt_input

  streamlink twitch.tv/$STREAMER_NAME best \
    --hls-duration $_max_length \
    --twitch-disable-hosting \
    --config ./auth/config.twitch \
    --logfile ./logs/streamlink.log \
    -O 2>/dev/null | xargs -r ./youtubeuploader/youtubeuploader \
    -cache ./auth/request.token \
    -secrets ./auth/yt_secrets.json \
    -metaJSON ./yt_input \
    -metaJSONout "./logs/youtubeuploader_$_current_timedate.log" \
    -filename - >/dev/null 2>&1 || upload_attempt=$((upload_attempt+1)) && kill $_collect_stream_info_pid && continue

  kill $_collect_stream_info_pid

  ./update_latest_video.sh || (touch ./twitch_to_youtube.lock && exit 1)
  log "Recording and uploading completed"
done

log "Exceeded upload attempts"
touch ./twitch_to_youtube.lock && exit 1