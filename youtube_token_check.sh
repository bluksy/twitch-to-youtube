#!/bin/ash

. "$(dirname "$0")/functions.sh"
. "$(dirname "$0")/youtube_api.sh"

while [ ! -f ./youtube_token_check.lock ]
do
  _youtube_api_token=""
  refresh_youtube_token _youtube_api_token

  _token_check_url=$(printf 'https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=%s' "$_youtube_api_token")

  _token_check_status_url=$(curl --write-out "%{http_code}" --silent --output "youtube_token_response.json" "${_token_check_url}")
  log "YT check status: $_token_check_status_url"

  if [ "$_token_check_status_url" -ne 200 ] ; then
    log "$(jq '.' youtube_token_response.json)"
    touch ./youtube_token_check.lock
    exit 1
  else
    sleep 1d
    continue
  fi
done

log "process is locked"
exit 0