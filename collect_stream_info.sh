#!/bin/ash

set -eao pipefail
. .env
set +a

. "$(dirname "$0")/functions.sh"
. "$(dirname "$0")/twitch_api.sh"

_old_stream_title=""
_start_in_seconds=$(date +%s)
printf '%s\\n' "Title changes:" > title_changes

while [ ! -f ./collect_stream_info.lock ]
do
  _stream_detail_body=""
  _stream_detail_status=""
  get_stream_detail _stream_detail_body _stream_detail_status

  if [ "$_stream_detail_status" = "200" ]; then
    _stream_title="$(echo "$_stream_detail_body" | jq '.data[0].title')"

    if [ "$_stream_title" = "null" ]; then
      log "stream ended"
      exit 0
    fi

    if [ "$_stream_title" != "$_old_stream_title" ]; then
      if [ "$_old_stream_title" = "" ]; then
        _timestamp="00:00:00"
      else
        _current_in_seconds=$(date +%s)
        _diff_sec=$(expr ${_current_in_seconds} - ${_start_in_seconds})
        _timestamp=$(date +%H:%M:%S -ud @"${_diff_sec}")
      fi

      log "Refreshing title"
      printf '%s %s\\n' "${_timestamp}" "${_stream_title:1:-1}" >> ./title_changes

      _old_stream_title="$_stream_title"
    fi

    sleep 1m
    continue
  elif [ "$_stream_detail_status" = "000" ]; then
    log "network error"
    sleep 1m
    continue
  else
    log "$(echo "$_stream_detail_body" | jq '.')"
    touch ./collect_stream_info.lock
    exit 1
  fi
done

log "process is locked"
exit 0