#!/bin/bash

INSTALLED_MARKER="ForgeAlreadyInstalled.txt"

if [ ! -f "$INSTALLED_MARKER" ]; then
    echo "Forge not installed. Installing now..."
    
    if [[ ${SERVER_JARFILE} == *installer.jar ]]; then
        java -jar ${SERVER_JARFILE} --installServer
        rm ${SERVER_JARFILE}
        FORGE_JAR=$(ls forge-*-universal.jar forge-*.jar | grep -v installer | head -1)
        echo "export SERVER_JARFILE=$FORGE_JAR" >> /home/container/.bashrc
        source /home/container/.bashrc
    fi

    touch "$INSTALLED_MARKER"
    echo "Forge installed successfully."
else
    echo "Forge already installed. Skipping installation."
fi

if [ -z "$SERVER_JARFILE" ]; then
    export SERVER_JARFILE=$(ls forge-*-universal.jar forge-*.jar | grep -v installer | head -1)
    echo "export SERVER_JARFILE=$SERVER_JARFILE" >> /home/container/.bashrc
    source /home/container/.bashrc
fi

echo "Starting Forge server with jar: $SERVER_JARFILE"
exec java -Xms256M -Xmx${SERVER_MEMORY}M -Dterminal.jline=false -Dterminal.ansi=true -jar ${SERVER_JARFILE} nogui
