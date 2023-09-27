#!/bin/ash

set -eao pipefail
. .env
set +a

. "$(dirname "$0")/functions.sh"

# $1: Return variable - new twitch API token
create_new_twitch_token () {
  local __result_token=$1

  local _twitch_token_request_body='{
      "client_id":"'${TWITCH_CLIENT_ID}'",
      "client_secret":"'${TWITCH_CLIENT_SECRET}'",
      "grant_type":"client_credentials"
    }'

  local _new_twitch_token
  _new_twitch_token=$(curl --silent -d "$_twitch_token_request_body" \
      -H "Content-Type: application/json" \
      -X POST https://id.twitch.tv/oauth2/token | \
      jq -r '.access_token')

  if [ "$__result_token" ]; then
    eval $__result_token="'${_new_twitch_token}'"
  else
    echo "$_new_twitch_token"
  fi
}

# $1: Return variable - valid twitch API token
get_twitch_token () {
  local __result_token=$1

  if [ -e auth/twitch_token ]; then
    local _current_twitch_token
    _current_twitch_token=$(cat auth/twitch_token)

    # validate token
    local _twitch_validate_twitch_stream_detail_status_code
    _twitch_validate_twitch_stream_detail_status_code=$(curl --silent -X GET 'https://id.twitch.tv/oauth2/validate' \
      --silent \
      --output "twitch_validate_response.json" \
      -H "Authorization: Bearer $_current_twitch_token" \
      --write-out '%{http_code}')

    if [ "$_twitch_validate_twitch_stream_detail_status_code" = "401" ]; then
      log "Refreshing token"
      create_new_twitch_token _current_twitch_token
      echo "$_current_twitch_token" > auth/twitch_token
    elif [ "$_twitch_validate_twitch_stream_detail_status_code" != "200" ]; then
      log "Validate token failed. Status code $_twitch_validate_twitch_stream_detail_status_code"
      log "$(jq '.' twitch_validate_response.json)"
    fi
  else
    create_new_twitch_token __current_twitch_token
    echo "$_current_twitch_token" > auth/twitch_token
  fi

  if [ "$__result_token" ]; then
    eval $__result_token="'${_current_twitch_token}'"
  else
    echo "$_current_twitch_token"
  fi
}

# $1: Return variable - stream detail response body
# $2: Return variable - stream detail response status code
get_stream_detail () {
  local __result_twitch_stream_detail_response_body=$1
  local __result_twitch_stream_detail_status_code=$2

  local _twitch_token
  get_twitch_token _twitch_token

  local _twitch_stream_detail_url
  _twitch_stream_detail_url=$(printf 'https://api.twitch.tv/helix/streams?user_login=%s&type=live' "$STREAMER_NAME")

  local _twitch_stream_detail_response
  _twitch_stream_detail_response=$(curl --silent \
      -H "Authorization: Bearer $_twitch_token" \
      -H "Client-Id: $TWITCH_CLIENT_ID" \
      --write-out '%{http_code}' \
      "${_twitch_stream_detail_url}")
  local _twitch_stream_detail_response_body=${_twitch_stream_detail_response::-3}
  local _twitch_stream_detail_status_code
  _twitch_stream_detail_status_code=$(printf "%s" "$_twitch_stream_detail_response" | tail -c 3)

  if [ "$__result_twitch_stream_detail_response_body" ] && [ "$__result_twitch_stream_detail_status_code" ]; then
    eval $__result_twitch_stream_detail_response_body="'${_twitch_stream_detail_response_body}'"
    eval $__result_twitch_stream_detail_status_code="'${_twitch_stream_detail_status_code}'"
  else
    echo "$_twitch_stream_detail_response"
  fi
}