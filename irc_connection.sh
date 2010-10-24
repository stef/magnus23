#!/bin/bash

source ./configuration.sh

mkdir -p "$IRC_CONNECTIONS"

while true
do
  (sleep 25; echo "/j $IRC_CHAN" > "$IRC_CONNECTIONS/$IRC_HOST/in") &
  ii \
    -i "$IRC_CONNECTIONS" \
    -s "$IRC_HOST" \
    -p "$IRC_PORT" \
    -n "$IRC_NICK" \
    -f "$IRC_NICK"
done
