#!/bin/sh

set -o allexport
. .env
set +o allexport

if [ -z "$STREAMER_NAME" ]; then
  echo "STREAMER_NAME variable missing"
  exit 1
fi

streamer_name=$STREAMER_NAME
retry_time=${RETRY_TIME:-30s}

echo "Streamer name: $streamer_name"
echo "Retry time: $retry_time"

if [ -n "$TIMEZONE" ]; then
  export TZ=${TIMEZONE}
  echo "Timezone: $TZ"
fi

while true
do
        # Check if streamer is live
        if streamlink "twitch.tv/$streamer_name" >/dev/null; then
            echo "$streamer_name live"
        else
            echo "$streamer_name not live at $(date)"
            sleep "$retry_time"
            continue
        fi

        timedate=$(date +%F)

        # Create the input file. Contains upload parameters
        echo '{"title":"'"${streamer_name}"' | '"$timedate"'","privacyStatus":"private","recordingDate":"'"$timedate"'","description":""}' > /tmp/yt_input

        # Cut after 10h because of youtube limit
        streamlink twitch.tv/$streamer_name best --hls-duration 10:00:00 --twitch-disable-hosting --config ./auth/config.twitch -O 2>/dev/null | ./youtubeuploader/youtubeuploader -cache ./auth/request.token -secrets ./auth/yt_secrets.json -metaJSON /tmp/yt_input -filename - >/dev/null 2>&1

        echo recording and uploading completed
done
