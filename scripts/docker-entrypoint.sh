#!/bin/bash

function exitColumnStore {
    monit unmonitor all
    cmapi-stop
    monit quit
}

# Clean Remnants
rm -f /var/run/*.pid
rm -f /var/lib/mysql/*.pid

# Start rsyslog
rsyslogd

trap exitColumnStore SIGTERM

exec "$@" &

wait
