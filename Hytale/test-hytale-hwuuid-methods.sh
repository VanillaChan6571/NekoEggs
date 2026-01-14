#!/bin/bash
# Hytale Hardware UUID In-Container/Docker Test
# Run this INSIDE the Hytale server docker container to see what it can read

echo "=========================================="
echo "Hytale Hardware UUID - Container Test"
echo "=========================================="
echo ""
echo "Testing all 4 methods Hytale uses..."
echo ""

SUCCESS=0
FAILED=0

echo "=========================================="
echo "Method 1: /etc/machine-id"
echo "=========================================="
if [ -f /etc/machine-id ]; then
    CONTENT=$(cat /etc/machine-id 2>&1)
    if [ -n "$CONTENT" ]; then
        echo "✓ File exists and readable"
        echo "Content: $CONTENT"
        echo "Length: ${#CONTENT} chars (should be 32)"
        if [ ${#CONTENT} -eq 32 ]; then
            echo "✓ Valid format!"
            ((SUCCESS++))
        else
            echo "✗ Invalid format (not 32 chars)"
            ((FAILED++))
        fi
    else
        echo "✗ File exists but empty"
        ((FAILED++))
    fi
else
    echo "✗ File does not exist"
    ((FAILED++))
fi
echo ""

echo "=========================================="
echo "Method 2: /var/lib/dbus/machine-id"
echo "=========================================="
if [ -f /var/lib/dbus/machine-id ]; then
    CONTENT=$(cat /var/lib/dbus/machine-id 2>&1)
    if [ -n "$CONTENT" ]; then
        echo "✓ File exists and readable"
        echo "Content: $CONTENT"
        echo "Length: ${#CONTENT} chars (should be 32)"
        if [ ${#CONTENT} -eq 32 ]; then
            echo "✓ Valid format!"
            ((SUCCESS++))
        else
            echo "✗ Invalid format (not 32 chars)"
            ((FAILED++))
        fi
    else
        echo "✗ File exists but empty"
        ((FAILED++))
    fi
else
    echo "✗ File does not exist"
    ((FAILED++))
fi
echo ""

echo "=========================================="
echo "Method 3: /sys/class/dmi/id/product_uuid"
echo "=========================================="
if [ -f /sys/class/dmi/id/product_uuid ]; then
    CONTENT=$(cat /sys/class/dmi/id/product_uuid 2>&1)
    if [ -n "$CONTENT" ]; then
        echo "✓ File exists and readable"
        echo "Content: $CONTENT"
        echo "✓ Valid format!"
        ((SUCCESS++))
    else
        echo "✗ File exists but empty"
        ((FAILED++))
    fi
else
    echo "✗ File does not exist (normal for containers)"
fi
echo ""

echo "=========================================="
echo "Method 4: dmidecode command"
echo "=========================================="
if command -v dmidecode &> /dev/null; then
    UUID=$(dmidecode -s system-uuid 2>&1)
    if [ $? -eq 0 ] && [ -n "$UUID" ]; then
        echo "✓ Command exists and works"
        echo "UUID: $UUID"
        ((SUCCESS++))
    else
        echo "✗ Command exists but failed"
        echo "Output: $UUID"
        ((FAILED++))
    fi
else
    echo "✗ Command not found (normal)"
fi
echo ""

echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo "Working methods: $SUCCESS"
echo "Failed methods: $FAILED"
echo ""

if [ $SUCCESS -gt 0 ]; then
    echo "✓ SUCCESS: At least one method works!"
    echo "Hytale should be able to get hardware UUID."
else
    echo "✗ FAILURE: No methods work!"
    echo ""
    echo "This means:"
    echo "  - Machine-id files are not mounted in this container"
    echo "  - You need to configure Wings to mount them"
    echo ""
    echo "On the Wings HOST (not in container), add to /etc/pterodactyl/config.yml:"
    echo ""
    echo "docker:"
    echo "  container:"
    echo "    mounts:"
    echo "      - source: /etc/machine-id"
    echo "        target: /etc/machine-id"
    echo "        read_only: true"
    echo "      - source: /var/lib/dbus/machine-id"
    echo "        target: /var/lib/dbus/machine-id"
    echo "        read_only: true"
    echo ""
    echo "Then: systemctl restart wings"
    echo "And REINSTALL this Hytale server"
fi

echo ""
echo "=========================================="
echo "Additional Info"
echo "=========================================="
echo "Current user: $(whoami)"
echo "User ID: $(id)"
echo ""