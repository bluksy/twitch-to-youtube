#!/bin/sh

REFRESH_BODY='{
  "client_id":"'$(jq -r '.web.client_id' ./auth/yt_secrets.json)'",
  "client_secret":"'$(jq -r '.web.client_secret' ./auth/yt_secrets.json)'",
  "refresh_token":"'$(jq -r '.refresh_token' ./auth/request.token)'",
  "grant_type":"refresh_token"
}'

curl --silent -d "$REFRESH_BODY" \
     -H "Content-Type: application/json" \
     -X POST https://www.googleapis.com/oauth2/v4/token | \
     jq -r '.access_token' > ./auth/new_token