#!/bin/ash

log ()
{
  printf "[%s] ${0##*/} | %s\n" "$(date)" "$1"
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