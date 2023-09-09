#!/bin/sh

# wait for listener to start
sleep 5s
supervisorctl start youtube-token-check
supervisorctl start twitch-to-youtube
