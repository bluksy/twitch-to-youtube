#!/bin/ash

set -ea
. .env
set +a

. "$(dirname "$0")/functions.sh"

if [ -z "$1" ]; then
  log "Missing stream title argument"
  exit 1
fi

_stream_title="$1"

if [ -z "$2" ]; then
  log "Missing description argument"
  exit 1
fi

_description="$2"

if [ -z "$3" ]; then
  log "Missing max length argument"
  exit 1
fi

_max_length="$3"

if [ -z "$4" ]; then
  log "Missing recording id argument"
  exit 1
fi

_recording_id="$4"

if [ -z "$STREAMER_NAME" ]; then
  log "STREAMER_NAME variable missing"
  exit 1
fi

if [ ! -f ./auth/yt_secrets.json ]; then
    log "File ./auth/yt_secrets.json does not exist"
    exit 1
fi

if [ ! -f ./auth/request.token ]; then
    log "File ./auth/request.token does not exist"
    exit 1
fi

if [ -n "$TIMEZONE" ]; then
  export TZ=${TIMEZONE}
fi

if [ -n "$RECORDING_PATH" ]; then
  # let's assume 3GB per hour
  _minimum_required_space=$(($MAX_LENGTH_IN_HOURS * 3 * 1024 * 1024))
  if [ $(df /app/recordings | tail -n1 | awk '{print $4}') -gt $_minimum_required_space ]; then
    _recording_path="/app/recordings/$STREAMER_NAME"_{time:%Y-%m-%dT%H:%M}_{id}.ts
  else
    log "Not enough space in recording path. Need at least $_minimum_required_space bytes!"
    _recording_path="/dev/null"
  fi
else
  _recording_path="/dev/null"
fi

./collect_stream_info.sh "$_recording_id" &
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
}' "${_youtube_title}" "${_current_timedate}" "${_description}" > "./yt_input.$_recording_id"

streamlink "twitch.tv/$STREAMER_NAME" best \
  --hls-duration "$_max_length" \
  --twitch-disable-hosting \
  --config ./auth/config.twitch \
  --logfile ./logs/streamlink.log \
  --progress no \
  --record-and-pipe "$_recording_path" | xargs -r ./youtubeuploader/youtubeuploader \
  -cache ./auth/request.token \
  -secrets ./auth/yt_secrets.json \
  -metaJSON "./yt_input.$_recording_id" \
  -metaJSONout "./yt_output.$_recording_id" \
  -filename - >/dev/null 2>&1 || true

kill $_collect_stream_info_pid
rm "./yt_input.$_recording_id"

./update_latest_video.sh "$_recording_id"
rm "./yt_output.$_recording_id"
log "Recording and uploading of '$_stream_title' completed (ID: $_recording_id)"