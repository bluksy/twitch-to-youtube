#!/bin/ash

set -eao pipefail
. .env
set +a

. "$(dirname "$0")/functions.sh"

if [ -f ./twitch_to_youtube.lock ]; then
  log "process is locked"
  exit 0
fi

check_vars STREAMER_NAME YT_CHANNEL_ID MAX_LENGTH_IN_HOURS

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

if [ ! -f "./yt_quota" ]; then
  log "Creating yt_quota file"
  echo 0 > ./yt_quota
fi

if [ -n "$TIMEZONE" ]; then
  export TZ=${TIMEZONE}
  log "Timezone: $TZ"
fi

_retry_time=${RETRY_TIME:-60s}
_description=${DESCRIPTION:-""}
_max_length_string="$MAX_LENGTH_IN_HOURS:00:00"
_max_length=${_max_length_string:-"8:00:00"}

log "Streamer name: $STREAMER_NAME"
log "Retry time: $_retry_time"
log "Description: $_description"
log "Max length: $_max_length"

while [ ! -f ./twitch_to_youtube.lock ]; do
  _stream_title=$(streamlink twitch.tv/"$STREAMER_NAME" -j | jq '.metadata?.title?' || true)
  _stream_title=${_stream_title:-null}

  if [ "$(date -u +%H%M)" = "0800" ]; then
    log "Resetting yt_quota file"
    echo 0 > ./yt_quota
  fi

  # Check if streamer is live
  if [ "$_stream_title" != null ]; then
    _recording_id=$(xxd -l8 -p /dev/urandom)
    log "$STREAMER_NAME is live" "$_recording_id"
    log "Recording ID: $_recording_id"
    log "Current quota: $(cat ./yt_quota)" "$_recording_id"
  else
    if [ "$(date +%M)" = "00" ]; then
      log "$STREAMER_NAME is not live"
    fi

    sleep "$_retry_time"
    continue
  fi

  ./record_stream.sh "$_stream_title" "$_description" "$_max_length" "$_recording_id" &
  _record_stream_pid=$!
  _segment_end=$(date -d "@$(($(date +%s) + $((MAX_LENGTH_IN_HOURS * 3600 - 15))))" +"%s")

  # this loop checks if recording process is still active
  # this loop also starts new recording 15s before the max length is about to exceed
  while true; do
    if ps | grep "${_record_stream_pid}[^[]" >/dev/null ; then
      if [ "$(date +%s)" -ge "$_segment_end" ]; then
        log "Recording almost exceeded max length - starting new recording" "$_recording_id"
        continue 2
      else
        if [ "$(date +%M)" = "00" ] && [ "$(date +%S)" -lt "10" ]; then
          log "Recording of '$_stream_title' still running" "$_recording_id"
        fi
        # process is still running
        sleep 10s
        continue
      fi
    else
        # If the process is already terminated, then there are 2 cases:
        # 1) the process executed and stop successfully
        # 2) it is terminated abnormally

        # check if process executed successfully or not
        if wait $_record_stream_pid; then
          log "Recording exited successfully" "$_recording_id"
          ./update_videos.sh

          continue 2
        else
          # process terminated abnormally
          log "Recording failed (returned $?)" "$_recording_id"
          continue 2
        fi
    fi
  done
done

touch ./twitch_to_youtube.lock && exit 1