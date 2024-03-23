#!/bin/ash

set -eao pipefail
. .env
set +a

. "$(dirname "$0")/functions.sh"
. "$(dirname "$0")/youtube_api.sh"
. "$(dirname "$0")/twitch_api.sh"
. "$(dirname "$0")/archive_api.sh"

if [ ! -f "./stream_ids" ]; then
  log "stream_ids file missing"
  exit 1
fi

_youtube_api_token=""
refresh_youtube_token _youtube_api_token
_vod_id=""
get_latest_vod_id _vod_id
_video_counter=0

while IFS='' read -r _recording_id || [ -n "${_recording_id}" ]; do
  if [ ! -f "./yt_output.$_recording_id" ]; then
    log "Output from youtubeuploader missing" "$_recording_id"
    rm "./title_changes.$_recording_id" || true
    exit 1
  fi

    set -- "$@" "$(jq -r '.id' < "./yt_output.$_recording_id")"
    _video_counter=$((_video_counter + 1))
done < stream_ids

while IFS='' read -r _recording_id || [ -n "${_recording_id}" ]; do
  log "processing video update" "$_recording_id"

  # Get publish delay from env variables; default is 1 day
  PUBLISH_DELAY_SECONDS=${PUBLISH_DELAY_SECONDS:-86400}

  _current_video_detail=$(cat "./yt_output.$_recording_id")
  _current_video_id=$(echo "$_current_video_detail" | jq '.id')
  _current_video_id=${_current_video_id:1:-1}
  _current_video_title=$(echo "$_current_video_detail" | jq '.snippet.title')
  _current_video_title=${_current_video_title:1:-1}
  _current_video_category=$(echo "$_current_video_detail" | jq '.snippet.categoryId')
  _current_video_category=${_current_video_category:1:-1}
  log "youtubeuploader output: $_current_video_detail" "$_recording_id"

  _part=0
  _description=""

  for _video_id in "$@"; do
    _part=$((_part + 1))

    if [[ "$_video_id" != "$_current_video_id" ]]; then
      _description=$(printf '%sPART %s: https://www.youtube.com/watch?v=%s\\n' "${_description}" ${_part} "${_video_id}")
    else
      _duration=10800

      if [ -f "./recording_duration.$_recording_id" ]; then
        _duration=$(cat "./recording_duration.$_recording_id")
        rm "./recording_duration.$_recording_id"
      fi

      _patch_vod_request_body='{
        "vodId": "'$_vod_id'",
        "part": "'$_part'",
        "youtubeId": "'$_current_video_id'",
        "duration": '$_duration'
      }'

      if [[ "$_video_counter" -ne 1 ]] && [[ ${#_current_video_title} -lt 93 ]]; then
        _current_video_title=$(printf '%s part %s' "${_current_video_title}" ${_part})
      fi
    fi
  done

  # if title_changes file doesn't exist then use just description from env variable
  if [ ! -f "./title_changes.$_recording_id" ];
  then
    _description=$(printf '%s\\n%s' "${_description}" "${DESCRIPTION}" )
  else
    _description=$(printf '%s\\n%s\\n%s' "${_description}" "$(cat "./title_changes.$_recording_id")" "${DESCRIPTION}" )
    rm "./title_changes.$_recording_id"
  fi

  if [ "$PUBLISH_DELAY_SECONDS" -lt 0 ]; then
    # Build the JSON data for the API request
    _update_video_request_body='{
      "id": "'$_current_video_id'",
      "status": {
        "privacyStatus": "private",
        "embeddable": true
      },
      "snippet": {
        "title":"'$_current_video_title'",
        "description":"'$_description'",
        "categoryId":"'$_current_video_category'"
      }
    }'
    else
      _current_timestamp=$(date -u +%s)

      _delayed_timestamp=$((_current_timestamp + PUBLISH_DELAY_SECONDS))

      # Convert timestamp to RFC3339 format
      _publish_time=$(date -u -d "@$_delayed_timestamp" +"%Y-%m-%dT%H:%M:%SZ")

      # Build the JSON data for the API request
      _update_video_request_body='{
        "id": "'$_current_video_id'",
        "status": {
          "publishAt": "'$_publish_time'",
          "privacyStatus": "private",
          "embeddable": true
        },
        "snippet": {
          "title":"'$_current_video_title'",
          "description":"'$_description'",
          "categoryId":"'$_current_video_category'"
        }
      }'
  fi

  update_video "$_youtube_api_token" "$_update_video_request_body" "$_recording_id"

  if [ -n "$ARCHIVE_API_TOKEN" ]; then
    patch_youtube_info "$_patch_vod_request_body" "$_recording_id"
  fi
  rm "./yt_output.$_recording_id"
done < stream_ids

if [ -n "$ARCHIVE_API_TOKEN" ]; then
  _post_refresh_vod_request_body='{
    "vodId": "'$_vod_id'"
  }'

  post_refresh_vod "$_post_refresh_vod_request_body" "$_recording_id"
fi

rm stream_ids