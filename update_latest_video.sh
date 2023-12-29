#!/bin/ash

set -eao pipefail
. .env
set +a

. "$(dirname "$0")/functions.sh"
. "$(dirname "$0")/youtube_api.sh"

# Get publish delay from env variables; default is 1 day
PUBLISH_DELAY_SECONDS=${PUBLISH_DELAY_SECONDS:-86400}

# Create empty last_video_id file in case it doesn't exist
if [ ! -f ./last_video_id ];
then
    touch ./last_video_id
fi

_youtube_api_token=""
refresh_youtube_token _youtube_api_token

# Get the latest video ID and title
_latest_video_detail=""
_latest_video_category=""
get_latest_video_detail "$_youtube_api_token" _latest_video_detail
_latest_video_id=$(echo "$_latest_video_detail" | jq -r '.id.videoId')
_latest_video_title=$(echo "$_latest_video_detail" | jq '.snippet.title')
_latest_video_title=${_latest_video_title:1:-1}

# Get video category (required for update EP)
get_video_category "$_youtube_api_token" "$_latest_video_id" _latest_video_category

if [ "$(cat ./last_video_id)" = "${_latest_video_id}" ];
then
  log "video id same as last one"
  exit 0
fi

echo "${_latest_video_id}" > last_video_id

# Set the desired publish date and time in RFC3339 format
# Get current timestamp
_current_timestamp=$(date -u +%s)

# Calculate timestamp for tomorrow
_tomorrow_timestamp=$((_current_timestamp + PUBLISH_DELAY_SECONDS))

# Convert tomorrow's timestamp to RFC3339 format
_publish_time=$(date -u -d "@$_tomorrow_timestamp" +"%Y-%m-%dT%H:%M:%SZ")

log "Publish time: $_publish_time"

# if title_changes file doesn't exist then use just description from env variable
if [ ! -f ./title_changes ];
then
  _description="${DESCRIPTION}"
else
  _description=$(printf '%s\\n%s' "$(cat title_changes)" "${DESCRIPTION}" )
  rm ./title_changes
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
