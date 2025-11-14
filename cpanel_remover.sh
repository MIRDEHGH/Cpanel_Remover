#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display header
display_header() {
    clear
    echo "========================================================"
    echo "   PROFESSIONAL CPANEL COMPLETE REMOVAL TOOL"
    echo "   FOR UBUNTU/CENTOS - TWO-STAGE PROCESS"
    echo "========================================================"
    echo ""
}

# Function to create backup
create_backup() {
    local backup_type=$1
    local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    local backup_dir="/root/cpanel_backup_${timestamp}"
    
    log_info "Creating backup directory: ${backup_dir}"
    mkdir -p "${backup_dir}"
    
    case $backup_type in
        1)
            log_info "Performing FULL system backup..."
            cp -r /etc "${backup_dir}/" 2>/dev/null
            cp -r /home "${backup_dir}/" 2>/dev/null
            cp -r /var/www "${backup_dir}/" 2>/dev/null
            ;;
        2)
            log_info "Backing up websites only..."
            cp -r /var/www "${backup_dir}/" 2>/dev/null
            ;;
        3)
            log_info "Backing up databases only..."
            if command -v mysqldump &> /dev/null; then
                mkdir -p "${backup_dir}/databases"
                databases=$(mysql -e "SHOW DATABASES;" | grep -v Database | grep -v information_schema | grep -v performance_schema)
                for db in $databases; do
                    mysqldump "$db" > "${backup_dir}/databases/${db}.sql" 2>/dev/null
                done
            fi
            ;;
        4)
            log_info "Backing up home directories only..."
            cp -r /home "${backup_dir}/" 2>/dev/null
            ;;
        5)
            log_info "Backing up websites and databases..."
            cp -r /var/www "${backup_dir}/" 2>/dev/null
            if command -v mysqldump &> /dev/null; then
                mkdir -p "${backup_dir}/databases"
                databases=$(mysql -e "SHOW DATABASES;" | grep -v Database | grep -v information_schema | grep -v performance_schema)
                for db in $databases; do
                    mysqldump "$db" > "${backup_dir}/databases/${db}.sql" 2>/dev/null
                done
            fi
            ;;
        *)
            log_warning "No backup selected"
            return 1
            ;;
    esac
    
    # Create backup info file
    cat > "${backup_dir}/backup_info.txt" << EOF
Backup created: ${timestamp}
Backup type: ${backup_type}
Backup location: ${backup_dir}
EOF
    
    log_success "Backup completed: ${backup_dir}"
}

# Function to display backup menu
backup_menu() {
    echo ""
    echo "=== BACKUP OPTIONS ==="
    echo "1) Full backup (Recommended)"
    echo "2) Websites only"
    echo "3) Databases only"
    echo "4) Home directories only"
    echo "5) Websites + Databases"
    echo "6) No backup (NOT RECOMMENDED)"
    echo ""
    
    while true; do
        read -p "Select backup option (1-6): " backup_choice
        case $backup_choice in
            1|2|3|4|5)
                create_backup "$backup_choice"
                break
                ;;
            6)
                log_warning "You selected NO BACKUP. This is risky!"
                read -p "Type 'CONFIRM_NO_BACKUP' to continue without backup: " confirm_no_backup
                if [[ "$confirm_no_backup" == "CONFIRM_NO_BACKUP" ]]; then
                    break
                else
                    echo "Please select a valid backup option."
                fi
                ;;
            *)
                echo "Invalid option. Please select 1-6."
                ;;
        esac
    done
}

# Function to create post-boot script
create_postboot_script() {
    cat > /root/cpanel_postboot_check.sh << 'EOF'
#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[POST-BOOT CLEANUP] Starting final cPanel cleanup...${NC}"

# Final scan for cPanel leftovers
echo -e "${YELLOW}[POST-BOOT] Scanning for leftover cPanel files...${NC}"
leftovers=$(find / -name "*cpanel*" -o -name "*whm*" -o -name "*cpsrvd*" 2>/dev/null | grep -v "/proc" | grep -v "/sys")

if [[ -n "$leftovers" ]]; then
    echo -e "${YELLOW}[POST-BOOT] Found leftover files:${NC}"
    echo "$leftovers"
    echo -e "${YELLOW}[POST-BOOT] Removing leftover files...${NC}"
    echo "$leftovers" | xargs rm -rf 2>/dev/null
    echo -e "${GREEN}[POST-BOOT] Leftover files removed.${NC}"
else
    echo -e "${GREEN}[POST-BOOT] No leftover cPanel files found.${NC}"
fi

# Final user cleanup
echo -e "${YELLOW}[POST-BOOT] Final user cleanup...${NC}"
users_to_delete=$(grep -E "cpanel|whm|cphulk|cpsrvd" /etc/passwd | cut -d: -f1)
for u in $users_to_delete; do
    userdel -r "$u" 2>/dev/null && echo -e "${GREEN}[POST-BOOT] Deleted user: $u${NC}"
done

# Cleanup script itself and systemd service
echo -e "${YELLOW}[POST-BOOT] Cleaning up removal tools...${NC}"
systemctl disable cpanel-postboot.service 2>/dev/null
rm -f /etc/systemd/system/cpanel-postboot.service
systemctl daemon-reload

# Remove this script
rm -f /root/cpanel_postboot_check.sh

echo -e "${GREEN}[POST-BOOT] cPanel removal completed successfully!${NC}"
echo -e "${GREEN}[POST-BOOT] All cleanup tools have been removed.${NC}"

EOF

    chmod +x /root/cpanel_postboot_check.sh
}

# Function to create systemd service for post-boot cleanup
create_postboot_service() {
    cat > /etc/systemd/system/cpanel-postboot.service << EOF
[Unit]
Description=cPanel Post-Boot Cleanup
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /root/cpanel_postboot_check.sh
RemainAfterExit=no
User=root

[Install]
WantedBy=multi-user.target

EOF

    systemctl daemon-reload
    systemctl enable cpanel-postboot.service
}

# Main removal function
main_removal() {
    display_header
    
    # Final warning
    log_warning "THIS IS A DESTRUCTIVE OPERATION!"
    log_warning "All cPanel data and services will be PERMANENTLY removed."
    echo ""
    log_warning "Type 'YES' exactly to continue: "
    read -r final_confirm
    
    if [[ "$final_confirm" != "YES" ]]; then
        log_error "Aborted. Please type YES exactly to continue."
        exit 1
    fi

    # Backup selection
    backup_menu

    # Stop cPanel services
    log_info "Stopping cPanel services..."
    systemctl stop cpanel 2>/dev/null
    systemctl disable cpanel 2>/dev/null
    /usr/local/cpanel/scripts/restartsrv_cpsrvd --stop 2>/dev/null
    
    # Kill remaining processes
    log_info "Killing cPanel processes..."
    killall -9 cpdavd cphulkd cpsrvd httpd 2>/dev/null
    pkill -f cpanel 2>/dev/null

    # Find and display cPanel files
    log_info "Searching for cPanel files..."
    cpanel_files=$(find / -iname "*cpanel*" -o -iname "*whm*" 2>/dev/null | head -50)
    
    if [[ -n "$cpanel_files" ]]; then
        echo ""
        log_warning "Found cPanel files (first 50):"
        echo "$cpanel_files"
        echo ""
        
        read -p "Type 'YES' to DELETE ALL these files: " delete_confirm
        if [[ "$delete_confirm" == "YES" ]]; then
            log_info "Removing cPanel files and directories..."
            find / -iname "*cpanel*" -exec rm -rf {} \; 2>/dev/null
            find / -iname "*whm*" -exec rm -rf {} \; 2>/dev/null
            
            # Specific directories
            rm -rf /usr/local/cpanel
            rm -rf /usr/local/cpanel-whm
            rm -rf /var/cpanel
            rm -rf /etc/cpanel
            rm -rf /root/.cpanel
            rm -rf /var/log/cpanel
            rm -rf /tmp/cpanel*
            
            log_success "cPanel files removed."
        else
            log_error "File deletion aborted."
            exit 1
        fi
    fi

    # Remove cron jobs
    log_info "Removing cPanel cron jobs..."
    crontab -l | grep -v "cpanel" | grep -v "whm" | crontab -
    rm -f /etc/cron.d/cpanel*
    rm -f /etc/cron.d/whm*
    rm -f /var/spool/cron/root

    # Remove cPanel users
    log_info "Removing cPanel users..."
    users_to_delete=$(grep -E "cpanel|whm|cphulk|cpsrvd" /etc/passwd | cut -d: -f1)
    for u in $users_to_delete; do
        userdel -r "$u" 2>/dev/null && log_success "Deleted user: $u"
    done

    # Remove cPanel-installed services
    log_info "Removing cPanel-installed services..."
    if command -v apt &> /dev/null; then
        # Ubuntu/Debian
        apt remove --purge -y apache2 apache2-utils php* mysql-server mariadb-server 2>/dev/null
        apt autoremove -y
        apt autoclean -y
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        yum remove -y httpd php mysql mariadb 2>/dev/null
        yum autoremove -y
    fi

    # Create post-boot cleanup script
    log_info "Creating post-boot cleanup script..."
    create_postboot_script
    create_postboot_service

    # Final message
    echo ""
    log_success "STAGE 1 COMPLETED!"
    log_info "A post-boot cleanup script has been created."
    log_info "The script will run automatically after reboot to remove any leftovers."
    echo ""
    
    read -p "Reboot now to complete the cleanup? (yes/no): " reboot_confirm
    if [[ "$reboot_confirm" == "yes" ]]; then
        log_info "System rebooting in 5 seconds..."
        sleep 5
        reboot
    else
        log_warning "Please reboot manually to complete the cleanup process."
        log_info "Post-boot script location: /root/cpanel_postboot_check.sh"
    fi
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Start main process
main_removal
