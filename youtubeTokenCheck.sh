#!/bin/sh

refresh_body='{"client_id":"'$(jq -r '.web.client_id' ./auth/yt_secrets.json)'","client_secret":"'$(jq -r '.web.client_secret' ./auth/yt_secrets.json)'","refresh_token":"'$(jq -r '.refresh_token' ./auth/request.token)'","grant_type":"refresh_token"}'

access_token=$(curl --silent -d "$refresh_body" -H "Content-Type: application/json" -X POST https://www.googleapis.com/oauth2/v4/token | jq -r '.access_token')

url=$(printf 'https://www.googleapis.com/youtube/v3/i18nLanguages?access_token=%s' "$access_token")

status_code=$(curl --write-out "%{http_code}" --silent --output "yt_response.json" "${url}")
echo "YT check status: $status_code"

if [ "$status_code" -ne 200 ] ; then
  jq '.' yt_response.json
  exit 1
else
  exit 0
fi