#!/bin/ash

set -eao pipefail
. .env
set +a

. "$(dirname "$0")/functions.sh"

# $1: request body
# $2: recording id
patch_youtube_info () {
  local __patch_vod_request_body=$1
  local __recording_id=$2

  log "PATCH YOUTUBE INFO REQUEST | $(printf "%s" "$__patch_vod_request_body" | jq -c)" "$__recording_id"

  local _patch_youtube_info_response
  _patch_youtube_info_response=$(curl --silent \
      -X PATCH \
      -H "Authorization: Bearer $ARCHIVE_API_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$__patch_vod_request_body" \
      "${ARCHIVE_API_BASE_URL}/admin/vods/youtube")
  log "PATCH YOUTUBE INFO RESPONSE | $(printf "%s" "$_patch_youtube_info_response" | jq -c)" "$__recording_id"
}

# $1: request body
# $2: recording id
post_refresh_vod () {
  local __post_refresh_vod_request_body=$1
  local __recording_id=$2

  log "REFRESH VOD REQUEST | $(printf "%s" "$__post_refresh_vod_request_body" | jq -c)" "$__recording_id"

  local _post_refresh_vod_response
  _post_refresh_vod_response=$(curl --silent \
      -X POST \
      -H "Authorization: Bearer $ARCHIVE_API_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$__post_refresh_vod_request_body" \
      "${ARCHIVE_API_BASE_URL}/admin/vods/refresh")
  log "REFRESH VOD RESPONSE | $(printf "%s" "$_post_refresh_vod_response" | jq -c)" "$__recording_id"
}