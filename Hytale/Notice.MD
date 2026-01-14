# NOTICE: Hytale Hardware UUID Solutions

**Last Updated:** January 13, 2026

### If You Have Wings 1.12.1+

No configuration needed. `/etc/machine-id` is already available to all containers.

Just make sure your host has a valid machine-id:

```bash
# Check if it exists and has content
cat /etc/machine-id

# If empty or missing, create it:
dbus-uuidgen --ensure=/etc/machine-id
chmod 444 /etc/machine-id
```

Then restart your Hytale server. Hardware UUID warnings should be gone.

---

## Alternative Method: DMI Product UUID

If you're on older Wings, Using Custom Wings or Wings 1.12.1+ still doesn't work, use this method:

### What This Does

Makes `/sys/devices/virtual/dmi/id/product_uuid` readable by containers. This is the **3rd method** Hytale checks for hardware UUID.

### Advantages

- ✅ No Wings configuration needed
- ✅ Works with any Wings version
- ✅ Uses real hardware UUID from DMI
- ✅ More "authentic" than machine-id

### Important Note About UUID Format

**Hytale expects different formats from different sources:**

- `/etc/machine-id` → 32 hex chars **without dashes**: `a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6`
- `/sys/class/dmi/id/product_uuid` → UUID **with dashes**: `550e8400-e29b-41d4-a716-446655440000`
- `UUIDs shown here are example UUIDs and not real`

Hytale's code handles both formats correctly. The DMI method returns UUIDs with dashes, which is unexpected.

---

## Making DMI Readable at Boot

The `/sys` filesystem is virtual and resets on boot. You need to make the permission change persistent.

### Method 1: Systemd Service (Recommended)

**Best for:** Modern Linux systems (Ubuntu 16.04+, Debian 8+, CentOS 7+)

```bash
# Create the service file
sudo tee /etc/systemd/system/fix-dmi-permissions.service > /dev/null << 'EOF'
[Unit]
Description=Fix DMI product_uuid permissions for Pterodactyl containers
Documentation=https://github.com/pterodactyl/wings
After=local-fs.target
Before=wings.service

[Service]
Type=oneshot
ExecStart=/bin/chmod 444 /sys/devices/virtual/dmi/id/product_uuid
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable fix-dmi-permissions.service
sudo systemctl start fix-dmi-permissions.service

# Verify it worked
sudo systemctl status fix-dmi-permissions.service
ls -la /sys/devices/virtual/dmi/id/product_uuid
```

**Verify on next boot:**
```bash
sudo reboot
# After reboot:
ls -la /sys/devices/virtual/dmi/id/product_uuid
```

### Method 2: Cron @reboot

**Best for:** Simple setups, any Linux version

```bash
# Edit root's crontab
sudo crontab -e

# Add this line:
@reboot sleep 10 && chmod 444 /sys/devices/virtual/dmi/id/product_uuid
```

### Method 3: rc.local

**Best for:** Old-school Linux admins, older systems

```bash
# Create/edit rc.local
sudo nano /etc/rc.local

# Add before 'exit 0':
chmod 444 /sys/devices/virtual/dmi/id/product_uuid

# Make executable if needed
sudo chmod +x /etc/rc.local

# Enable rc-local service (if not already)
sudo systemctl enable rc-local.service
```

### Method 4: udev Rule

**Best for:** Advanced users, targeting specific hardware

```bash
# Create udev rule
sudo tee /etc/udev/rules.d/99-dmi-permissions.rules > /dev/null << 'EOF'
# Make DMI product_uuid readable by all users for Pterodactyl
SUBSYSTEM=="dmi", KERNEL=="id", ATTR{product_uuid}=="*", RUN+="/bin/chmod 444 /sys/devices/virtual/dmi/id/product_uuid"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Verify
ls -la /sys/devices/virtual/dmi/id/product_uuid
```

---

## Testing Your Setup

After applying any method, test it:

### 1. Check Host Permissions

```bash
ls -la /sys/devices/virtual/dmi/id/product_uuid
# Should show: -r--r--r-- (444)

cat /sys/devices/virtual/dmi/id/product_uuid
# Should show UUID with dashes
```

### 2. Test in Container

Upload `test-hytale-hwuuid-methods.sh` (download on github) Hytale Server and run:

```bash
bash test-hytale-hwuuid-methods.sh
```

Should show:
```
Method 3: /sys/class/dmi/id/product_uuid
✓ File exists and readable
Content: 550e8400-e29b-41d4-a716-446655440000
✓ Valid format!
```

### 3. Start Hytale Server

Check logs for the hardware UUID warning. Should be **gone**!

No more:
```
Failed to get Hardware UUID
Cannot derive encryption key
Cannot save credentials
```

### 4. Test Authentication Persistence

```bash
# Authenticate the server
/auth login device
# Follow the prompts

# Restart the server
# Check if you need to authenticate again
```

If it works, authentication should **persist** across restarts!

---

## Summary

### For Wings 1.12.1+
1. **Do nothing!** It's already handled
2. Just ensure host has valid `/etc/machine-id`
3. Restart Hytale servers to pick up the mount

### For Older Wings
1. Use **Method 1 (Systemd Service)** for DMI permissions
2. Or upgrade to Wings 1.12.1+

### For Both
- Wings 1.12.1+ mounts machine-id automatically
- DMI method is a good backup/alternative
- Both methods work simultaneously (Hytale checks both)

---

## Troubleshooting

### "Still getting hardware UUID warnings"

1. Check Wings version: `wings --version`
2. If 1.12.1+: Check host's `/etc/machine-id` has content
3. If older: Verify DMI permissions: `ls -la /sys/devices/virtual/dmi/id/product_uuid`
4. **Reinstall** Hytale server (existing containers don't pick up new mounts)
5. Run `test-in-container.sh` inside Hytale container to see what's available

### "DMI file doesn't exist"

Some VMs/containers don't expose DMI. In this case:
- Upgrade to Wings 1.12.1+ (uses machine-id instead)

### "Permissions reset after reboot"

You didn't make it persistent. Choose one of the boot methods above.

### "Wings mount doesn't work in 1.12.1+"

1. Verify Wings version: `wings --version`
2. Check Wings logs: `journalctl -u wings -f`
3. Ensure host machine-id exists: `cat /etc/machine-id`
4. Reinstall Hytale server (don't just restart)

---

## Additional Resources

- **Wings 1.12.1 Release Notes:** https://github.com/pterodactyl/wings/releases/tag/v1.12.1
- **Test Scripts:** See `test-hytale-hwuuid-methods.sh`
- **Pterodactyl Documentation:** https://pterodactyl.io/wings/1.0/

---

*Last updated: January 13, 2026 - The day Wings 1.12.1 was released and we figured this all out! 🎉*