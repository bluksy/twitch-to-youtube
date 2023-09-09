#!/bin/sh

while [ ! -f ./youtube_token_check.lock ]
do
  API_KEY=$(./refresh_token.sh)

  URL=$(printf 'https://www.googleapis.com/youtube/v3/i18nLanguages?access_token=%s' "$API_KEY")

  STATUS_CODE=$(curl --write-out "%{http_code}" --silent --output "yt_response.json" "${URL}")
  echo "YT check status: $STATUS_CODE"

  if [ "$STATUS_CODE" -ne 200 ] ; then
    jq '.' yt_response.json
    touch ./youtube_token_check.lock
    exit 1
  else
    sleep 1d
    continue
  fi
done

echo process is locked
exit 0