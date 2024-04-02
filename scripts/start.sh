#!/bin/busybox sh

# The goal of the logic in this script is to reduce unnecessary use of the access point (AP.)
# We do this by waiting for connectivity (with a timeout) at startup and after losing
# connectivity (RECOVERY_TIME). As soon as connectivity is achieved, control returns to the main loop and we
# avoid the need for the AP. Only if the connectivity wait times out do we launch the AP.
#
# This allows the AP to run for a longer time, being more confident that it is the only way
# to achieve connectivity.

# Verbose logging
function log() {
    local msg=$1
    if [[ $VERBOSE != false ]]; then
        echo "$msg"
    fi
}

# Call with timeout: `wait_connectivity 120`
# Call with timeout of `0` for a single run
#
# Call returns setting CONNECTED to `1` for connected, otherwise `0`
function wait_connectivity() {
    local timeout=$1

    if [ $timeout -eq 0 ]; then
        log "Checking for connectivity (once) ..."
        wget -q --spider --no-check-certificate 1.1.1.1
    else
        log "Waiting for connectivity for $timeout seconds ..."
        timeout $timeout busybox sh -c 'while true; do wget -q --spider --no-check-certificate 1.1.1.1; if [ $? -eq 0 ]; then break; fi; sleep 1; done' > /dev/null 2>&1
    fi

    if [ $? -eq 0 ]; then
        log "Connectivity status: Connected"
        CONNECTED=1
    else
        log "Connectivity status: Not connected"
        CONNECTED=0
    fi
}

# How long to wait for a connection at startup before launching the AP
if [[ ! -z $STARTUP_WAIT_TIME ]] 
    then
        startupTime=$STARTUP_WAIT_TIME
    else
        startupTime=10
fi

# This is the frequency at which we check for a connection.
if [[ ! -z $CHECK_CONN_FREQ ]] 
    then
        freq=$CHECK_CONN_FREQ
    else
        freq=60
fi

# If a connection is lost, wait this long for the connection to recover before starting the
# access point.
if [[ ! -z $RECOVERY_TIME ]] 
    then
        recovery=$RECOVERY_TIME
    else
        recovery=60
fi

# Initial check for a connection.
#
# We use a startup timeout to allow for the initial connection to be established.
wait_connectivity $startupTime

while [[ true ]]; do
    if [ $CONNECTED -eq 1 ]; then
        log "Your device is connected to the internet, will check again in $freq seconds."
        sleep $freq
        wait_connectivity 0

        # If we just lost connectivity, give it some time to recover before starting the access point
        if [ $CONNECTED -eq 0 ]; then
            log "Your device has lost connectivity... allowing $recovery seconds for recovery."
            wait_connectivity $recovery
        fi
    else
        log "Your device is not connected to the internet, starting up access point '${PORTAL_SSID}'."
        DBUS_SYSTEM_BUS_ADDRESS=unix:path=/host/run/dbus/system_bus_socket /usr/src/app/wifi-connect -u /usr/src/app/ui
        wait_connectivity $freq
    fi
done

/bin/busybox sh /usr/bin/balena-idle
