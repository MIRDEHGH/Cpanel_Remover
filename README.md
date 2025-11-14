# cPanel Complete Removal Tool

This is a simple two-stage Bash script to **completely remove cPanel** from Linux servers (Ubuntu or CentOS). 

It is designed for users who want to:

- Stop all cPanel services
- Remove cPanel files and directories
- Delete cPanel users and cron jobs
- Optionally create backups before removal
- Run a second script automatically after reboot to clean any leftovers
- Remove itself and the cleanup service after finishing

> ⚠️ **Warning:** This script is destructive. Make sure to backup your server or important data before running it.

## How it Works

1. **Before Reboot:**
   - Stop cPanel services
   - Optionally create backups
   - Delete main cPanel files
   - Remove users and cron jobs
   - Setup a post-boot script for final cleanup

2. **After Reboot:**
   - The post-boot script runs automatically
   - Scans the system for leftover cPanel files and users
   - Deletes anything found
   - Removes itself and the systemd service

## Usage
1.download and run it with this:
```bash
wget https://raw.githubusercontent.com/MIRDEHGH/Cpanel_Remover/main/remover.sh
# Then run
chmod +x remover.sh
sudo ./remover.sh
```
2. or Download or copy the script to your server.
3. Give execute permission:
   ```bash
   chmod +x remove_cpanel.sh
   sudo ./remove_cpanel.sh

Run as root:
```bash
sudo ./remove_cpanel.sh
```


  And follow the instructions in the terminal.
