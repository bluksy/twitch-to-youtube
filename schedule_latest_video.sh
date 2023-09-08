#!/bin/sh

set -eao pipefail
. .env
set +a

if [ ! -f ./last_video_id ];
then
    touch ./last_video_id
fi

# Set your YouTube API key
API_KEY=$(./refresh_token.sh)

# Get the latest video ID from the channel
VIDEO_ID=$(curl -s "https://www.googleapis.com/youtube/v3/search?access_token=${API_KEY}&channelId=${YT_CHANNEL_ID}&order=date&part=snippet&type=video&forMine=false&max_results=1" | jq -r '.items[0].id.videoId')

if [ "$(cat ./last_video_id)" = "${VIDEO_ID}" ];
then
  echo "video id same as last one"
  exit 1
fi

echo "Last uploaded video ID: ${VIDEO_ID}"
echo "${VIDEO_ID}" > last_video_id

# Set the desired publish date and time in RFC3339 format
# Get current timestamp
CURRENT_TIMESTAMP=$(date -u +%s)

PUBLISH_DELAY_SECONDS=${PUBLISH_DELAY_SECONDS:-86400}

# Calculate timestamp for tomorrow
TOMORROW_TIMESTAMP=$((CURRENT_TIMESTAMP + PUBLISH_DELAY_SECONDS))

# Convert tomorrow's timestamp to RFC3339 format
PUBLISH_TIME=$(date -u -d "@$TOMORROW_TIMESTAMP" +"%Y-%m-%dT%H:%M:%SZ")

echo "Publish time: $PUBLISH_TIME"

# Build the JSON data for the API request
JSON_DATA='{
  "id": "'$VIDEO_ID'",
  "status": {
    "publishAt": "'$PUBLISH_TIME'",
    "privacyStatus": "private"
  }
}'

# Make the API request using curl
curl -X PUT \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$JSON_DATA" \
  "https://www.googleapis.com/youtube/v3/videos?part=status&key=$API_KEY"