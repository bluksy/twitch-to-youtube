#!/bin/ash

set -eao pipefail
. .env
set +a

. "$(dirname "$0")/functions.sh"
. "$(dirname "$0")/youtube_api.sh"

if [ -z "$1" ]; then
  log "Missing recording id argument"
  exit 1
fi

_recording_id="$1"

if [ ! -f "./yt_output.$_recording_id" ];
then
  log "Output from youtubeuploader missing (ID: $_recording_id)"
  rm "./title_changes.$_recording_id" || true
  exit 1
fi

# Get publish delay from env variables; default is 1 day
PUBLISH_DELAY_SECONDS=${PUBLISH_DELAY_SECONDS:-86400}

_youtube_api_token=""
refresh_youtube_token _youtube_api_token

# Get the latest video ID and title
_latest_video_detail=$(cat "./yt_output.$_recording_id")
_latest_video_id=$(echo "$_latest_video_detail" | jq -r '.id')
_latest_video_title=$(echo "$_latest_video_detail" | jq '.snippet.title')
_latest_video_title=${_latest_video_title:1:-1}
_latest_video_category=$(echo "$_latest_video_detail" | jq '.snippet.categoryId')

log "youtubeuploader output: $_latest_video_detail"

# Set the desired publish date and time in RFC3339 format
# Get current timestamp
_current_timestamp=$(date -u +%s)

# Calculate timestamp for tomorrow
_tomorrow_timestamp=$((_current_timestamp + PUBLISH_DELAY_SECONDS))

# Convert tomorrow's timestamp to RFC3339 format
_publish_time=$(date -u -d "@$_tomorrow_timestamp" +"%Y-%m-%dT%H:%M:%SZ")

log "Publish time: $_publish_time"

# if title_changes file doesn't exist then use just description from env variable
if [ ! -f "./title_changes.$_recording_id" ];
then
  _description="${DESCRIPTION}"
else
  _description=$(printf '%s\\n%s' "$(cat "./title_changes.$_recording_id")" "${DESCRIPTION}" )
  rm "./title_changes.$_recording_id"
fi

# Build the JSON data for the API request
_update_video_request_body='{
  "id": "'$_latest_video_id'",
  "status": {
    "publishAt": "'$_publish_time'",
    "privacyStatus": "private"
  },
  "snippet": {
    "title":"'$_latest_video_title'",
    "description":"'$_description'",
    "categoryId":"'$_latest_video_category'"
  }
}'

update_video "$_youtube_api_token" "$_update_video_request_body"
