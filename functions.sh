#!/bin/ash

# $1: Log message
# $2: Recording ID
log ()
{
  printf "[%s] [%s] %s | %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%S")" "${2:-No ID}" "${0##*/}" "$1"
}

check_vars()
{
    var_names="$@"
    var_unset=false

    for var_name in $var_names; do
        [ -z "$(eval echo \$"$var_name")" ] && echo "$var_name is unset." && var_unset=true
    done

    [ "$var_unset" = true ] && exit 1
    return 0
}