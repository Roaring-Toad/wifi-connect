#!/bin/busybox sh

if [[ ! -z $CHECK_CONN_FREQ ]] 
    then
        freq=$CHECK_CONN_FREQ
    else
        freq=120
fi


sleep 5
PORTAL_WAS_RUN=0

while [[ true ]]; do
    if [[ $VERBOSE != false ]]; then echo "Checking internet connectivity ..."; fi
    wget --spider --no-check-certificate 1.1.1.1 > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        if [[ $VERBOSE != false ]]; then
            if [[ $PORTAL_WAS_RUN == 1 ]]; then
                echo "Your device was successfully connected to the internet, will check again in $freq seconds.";
            else
                echo "Your device is already connected to the internet, will check again in $freq seconds.";
            fi
        fi
        PORTAL_WAS_RUN=0
    else
        if [[ $VERBOSE != false ]]; then
            echo "Your device is not connected to the internet, starting up access point '${PORTAL_SSID}'."
        fi
        DBUS_SYSTEM_BUS_ADDRESS=unix:path=/host/run/dbus/system_bus_socket /usr/src/app/wifi-connect -u /usr/src/app/ui
        if [[ $VERBOSE != false ]]; then
            echo "The access point is stopped, will check for internet immediately."
        fi
        PORTAL_WAS_RUN=1
        continue
    fi

    sleep $freq
done


/bin/busybox sh /usr/bin/balena-idle