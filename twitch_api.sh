#!/bin/sh

set -eao pipefail
. .env
set +a

. "$(dirname "$0")/functions.sh"

create_new_token () {
  local __resultvar=$1

  local TOKEN_REQUEST_BODY='{
      "client_id":"'${TWITCH_CLIENT_ID}'",
      "client_secret":"'${TWITCH_CLIENT_SECRET}'",
      "grant_type":"client_credentials"
    }'

  local TOKEN=$(curl --silent -d "$TOKEN_REQUEST_BODY" \
      -H "Content-Type: application/json" \
      -X POST https://id.twitch.tv/oauth2/token | \
      jq -r '.access_token')

  if [ "$__resultvar" ]; then
    eval $__resultvar="'${TOKEN}'"
  else
    echo "$TOKEN"
  fi
}

get_token () {
  local __resultvar=$1

  if [ -e auth/twitch_token ]; then
    local TOKEN=$(cat auth/twitch_token)

    # validate token
    local validate_code=$(curl --silent -X GET 'https://id.twitch.tv/oauth2/validate' \
      --silent \
      -o /dev/null \
      -H "Authorization: Bearer $TOKEN" \
      --write-out '%{http_code}')

    if [ "$validate_code" = "401" ]; then
      log "Refreshing token"
      local TOKEN=$(create_new_token)
      echo "$TOKEN" > auth/twitch_token
    elif [ "$validate_code" != "200" ]; then
      log "Validate token failed. Status code $validate_code"
    fi
  else
    local TOKEN=$(create_new_token)
    echo "$TOKEN" > auth/twitch_token
  fi

  if [ "$__resultvar" ]; then
    eval $__resultvar="'${TOKEN}'"
  else
    echo "$TOKEN"
  fi
}

get_stream_detail () {
  local __resultbody=$1
  local __resultstatuscode=$2

  get_token twitch_token

  local URL=$(printf 'https://api.twitch.tv/helix/streams?user_login=%s' "$STREAMER_NAME")

  local RESPONSE=$(curl --silent \
      -H "Authorization: Bearer $twitch_token" \
      -H "Client-Id: $TWITCH_CLIENT_ID" \
      --write-out '%{http_code}' \
      "${URL}")
  local BODY=${RESPONSE::-3}
  local STATUS_CODE=$(printf "%s" "$RESPONSE" | tail -c 3)

  if [ "$__resultbody" ] && [ "$__resultstatuscode" ]; then
    eval $__resultbody="'${BODY}'"
    eval $__resultstatuscode="'${STATUS_CODE}'"
  else
    echo "$RESPONSE"
  fi
}