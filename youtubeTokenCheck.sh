#!/bin/sh

while [ ! -f ./youtubeTokenCheck.lock ]
do
  ./refreshToken.sh

  access_token=$(cat ./auth/new_token)

  url=$(printf 'https://www.googleapis.com/youtube/v3/i18nLanguages?access_token=%s' "$access_token")

  status_code=$(curl --write-out "%{http_code}" --silent --output "yt_response.json" "${url}")
  echo "YT check status: $status_code"

  if [ "$status_code" -ne 200 ] ; then
    jq '.' yt_response.json
    touch ./youtubeTokenCheck.lock
    exit 1
  else
    sleep 1d
    continue
  fi
done

echo process is locked