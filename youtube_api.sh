#!/bin/ash

set -eao pipefail
. .env
set +a

. "$(dirname "$0")/functions.sh"

# $1: Return variable - Valid Youtube token
refresh_youtube_token () {
  local __result_youtube_token=$1

  local _refresh_youtube_token_request_body
  _refresh_youtube_token_request_body='{
    "client_id":"'$(jq -r '.web.client_id' ./auth/yt_secrets.json)'",
    "client_secret":"'$(jq -r '.web.client_secret' ./auth/yt_secrets.json)'",
    "refresh_token":"'$(jq -r '.refresh_token' ./auth/request.token)'",
    "grant_type":"refresh_token"
  }'

  local _new_youtube_token
  _new_youtube_token=$(curl --silent -d "$_refresh_youtube_token_request_body" \
       -H "Content-Type: application/json" \
       -X POST https://www.googleapis.com/oauth2/v4/token | \
         jq -r '.access_token')

  if [ "$__result_youtube_token" ]; then
      eval $__result_youtube_token="'${_new_youtube_token}'"
    else
      echo "$_new_youtube_token"
    fi
}

# $1: Valid Youtube token
# $2: Return variable - video detail JSON
get_latest_video_detail () {
  local __youtube_token=$1
  local __result_video_detail=$2

  local _video_search_response_detail=""
  _video_search_response_detail=$(curl --silent \
     -H "Authorization: Bearer $__youtube_token" \
     "https://www.googleapis.com/youtube/v3/search?channelId=${YT_CHANNEL_ID}&order=date&part=snippet&type=video&forMine=false&max_results=1")
  log "VIDEO SEARCH RESPONSE | $(printf "%s" "$_video_search_response_detail" | jq -c)"

  local _video_detail=""
  _video_detail=$(echo "$_video_search_response_detail" | jq '.items[0]')

  if [ "$__result_video_detail" ]; then
    eval "$__result_video_detail="'${_video_detail}'""
  else
    echo "$_video_detail"
  fi
}

# $1: Valid Youtube token
# $2: Youtube video ID
# $3: Return variable - video category ID
get_video_category () {
  local __youtube_token=$1
  local __youtube_video_id=$2
  local __result_category_id=$3

  local _video_detail_response=""
  _video_detail_response=$(curl --silent \
    -H "Authorization: Bearer $__youtube_token" \
    "https://www.googleapis.com/youtube/v3/videos?part=snippet&id=${__youtube_video_id}")
  log "VIDEO DETAIL RESPONSE | $(printf "%s" "$_video_detail_response" | jq -c)"
  local _video_category=""
  _video_category=$(echo "$_video_detail_response" | jq -r '.items[0].snippet.categoryId')

  if [ "$__result_category_id" ]; then
    eval $__result_category_id="'${_video_category}'"
  else
    echo "$_video_category"
  fi
}

# $1 Valid Youtube token
# $2 Update request body
update_video () {
  local __youtube_token=$1
  local __request_body=$2
  local __recording_id=$3

  log "UPDATE VIDEO REQUEST | $(printf "%s" "$__request_body" | jq -c)"

  local _video_update_response=""
  _video_update_response=$(curl -X PUT \
    --silent \
    -H "Authorization: Bearer $__youtube_token" \
    -H "Content-Type: application/json" \
    -d "$__request_body" \
    "https://www.googleapis.com/youtube/v3/videos?part=status&part=snippet")
  log "UPDATE VIDEO RESPONSE | $(printf "%s" "$_video_update_response" | jq -c)" "$__recording_id"
}