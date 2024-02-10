#!/bin/ash

set -eao pipefail
. .env
set +a

. "$(dirname "$0")/functions.sh"
. "$(dirname "$0")/youtube_api.sh"

if [ ! -f "./stream_ids" ]; then
  log "stream_ids file missing"
  exit 1
fi

_youtube_api_token=""
refresh_youtube_token _youtube_api_token

while IFS='' read -r _recording_id || [ -n "${_recording_id}" ]; do
  if [ ! -f "./yt_output.$_recording_id" ]; then
    log "Output from youtubeuploader missing (ID: $_recording_id)"
    rm "./title_changes.$_recording_id" || true
    exit 1
  fi

    set -- "$@" "$(jq -r '.id' < "./yt_output.$_recording_id")"
done < stream_ids

while IFS='' read -r _recording_id || [ -n "${_recording_id}" ]; do
  log "processing update for recording ID $_recording_id"

  # Get publish delay from env variables; default is 1 day
  PUBLISH_DELAY_SECONDS=${PUBLISH_DELAY_SECONDS:-86400}

  # Get the latest video ID and title
  _latest_video_detail=$(cat "./yt_output.$_recording_id")
  _latest_video_id=$(echo "$_latest_video_detail" | jq -r '.id')
  _latest_video_title=$(echo "$_latest_video_detail" | jq '.snippet.title')
  _latest_video_title=${_latest_video_title:1:-1}
  _latest_video_category=$(echo "$_latest_video_detail" | jq '.snippet.categoryId')
  _latest_video_category=${_latest_video_category:1:-1}
  log "youtubeuploader output (Recording ID: $_recording_id): $_latest_video_detail"
  rm "./yt_output.$_recording_id"

  _part=1
  _description=""

  for _video_id in "$@"; do
    if [[ "$_video_id" = "$_latest_video_id" ]]; then
      if [[ ${#_latest_video_title} -lt 93 ]]; then
        _latest_video_title=$(printf "%s part %s" _latest_video_title _part)
      fi

      _part=$((_part + 1))
      continue;
    fi

    _description=$(printf "%sPART %s: https://www.youtube.com/watch?v=%s\\n" _part_string _part _video_id)
    _part=$((_part + 1))
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
      "id": "'$_latest_video_id'",
      "status": {
        "privacyStatus": "private"
      },
      "snippet": {
        "title":"'$_latest_video_title'",
        "description":"'$_description'",
        "categoryId":"'$_latest_video_category'"
      }
    }'
    else
      _current_timestamp=$(date -u +%s)

      _delayed_timestamp=$((_current_timestamp + PUBLISH_DELAY_SECONDS))

      # Convert timestamp to RFC3339 format
      _publish_time=$(date -u -d "@$_delayed_timestamp" +"%Y-%m-%dT%H:%M:%SZ")

      log "Publish time: $_publish_time"

      # Build the JSON data for the API request
      _update_video_request_body='{
        "id": "'$_latest_video_id'",
        "status": {
          "publishAt": "'$_publish_time'",
          "privacyStatus": "private"
        },
        "snippet": {
          "title":"'$_latest_video_title'",
          "description":"'$_description'",
          "categoryId":"'$_latest_video_category'"
        }
      }'
  fi

  update_video "$_youtube_api_token" "$_update_video_request_body"
done < stream_ids

rm stream_ids