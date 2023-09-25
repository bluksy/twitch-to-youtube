#!/bin/ash

log () {
  printf "[%s] ${0##*/} | %s\n" "$(date)" "$1"
}