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
    echo "   ULTIMATE CPANEL COMPLETE REMOVAL TOOL"
    echo "   SUPER AGGRESSIVE MODE - NO TRACE LEFT"
    echo "========================================================"
    echo ""
}

# Function to create backup
create_backup() {
    local backup_dir="/root/cpanel_backup_$(date +"%Y-%m-%d_%H-%M-%S")"
    
    log_info "Creating backup: $backup_dir"
    mkdir -p "$backup_dir"
    
    # Essential backups only
    cp -r /home "$backup_dir/" 2>/dev/null
    cp -r /var/www "$backup_dir/" 2>/dev/null
    
    # Database backup
    if command -v mysqldump &> /dev/null; then
        mkdir -p "$backup_dir/databases"
        databases=$(mysql -e "SHOW DATABASES;" 2>/dev/null | grep -v Database | grep -v information_schema | grep -v performance_schema | grep -v mysql)
        for db in $databases; do
            mysqldump "$db" > "$backup_dir/databases/${db}.sql" 2>/dev/null
        done
    fi
    
    log_success "Backup completed: $backup_dir"
}

# AGGRESSIVE CPANEL REMOVAL FUNCTIONS

remove_cpanel_packages() {
    log_info "Removing cPanel packages..."
    
    # Ubuntu/Debian
    if command -v apt &> /dev/null; then
        # Remove all cPanel related packages
        dpkg -l | grep cpanel | awk '{print $2}' | xargs -r dpkg --purge --force-all
        dpkg -l | grep whm | awk '{print $2}' | xargs -r dpkg --purge --force-all
        
        # Fix broken packages
        apt --fix-broken install -y
        apt autoremove -y
        apt autoclean -y
    fi
    
    # CentOS/RHEL
    if command -v rpm &> /dev/null; then
        rpm -qa | grep -i cpanel | xargs -r rpm -e --nodeps
        rpm -qa | grep -i whm | xargs -r rpm -e --nodeps
    fi
}

remove_cpanel_files() {
    log_info "Removing cPanel files and directories..."
    
    # AGGRESSIVE FILE REMOVAL
    find / -name "*cpanel*" -exec rm -rf {} \; 2>/dev/null
    find / -name "*whm*" -exec rm -rf {} \; 2>/dev/null
    find / -name "*cpsrvd*" -exec rm -rf {} \; 2>/dev/null
    find / -name "*cphulk*" -exec rm -rf {} \; 2>/dev/null
    find / -name "*cpdavd*" -exec rm -rf {} \; 2>/dev/null
    
    # Specific directories - FORCE REMOVE
    rm -rf /usr/local/cpanel
    rm -rf /usr/local/cpanel-whm
    rm -rf /var/cpanel
    rm -rf /etc/cpanel
    rm -rf /var/log/cpanel
    rm -rf /tmp/cpanel*
    rm -rf /root/.cpanel
    rm -rf /home/cpanel*
    rm -rf /home/whm*
    
    # Remove cPanel repositories
    rm -rf /etc/apt/sources.list.d/cpanel*
    rm -rf /etc/yum.repos.d/cpanel*
}

remove_cpanel_services() {
    log_info "Stopping and removing cPanel services..."
    
    # Kill all cPanel processes
    pkill -f cpanel
    pkill -f whm
    pkill -f cpsrvd
    pkill -f cphulkd
    pkill -f cpdavd
    
    # Remove systemd services
    systemctl stop cpanel 2>/dev/null
    systemctl disable cpanel 2>/dev/null
    systemctl stop cpanel-whm 2>/dev/null
    systemctl disable cpanel-whm 2>/dev/null
    
    rm -f /etc/systemd/system/cpanel*
    rm -f /etc/systemd/system/whm*
    systemctl daemon-reload
}

remove_cpanel_users() {
    log_info "Removing cPanel users..."
    
    # Remove cPanel created users
    users_to_delete=$(grep -E "cpanel|whm|cphulk|cpsrvd" /etc/passwd | cut -d: -f1)
    for user in $users_to_delete; do
        userdel -r "$user" 2>/dev/null && log_success "Deleted user: $user"
    done
    
    # Remove cPanel groups
    groups_to_delete=$(grep -E "cpanel|whm|cphulk" /etc/group | cut -d: -f1)
    for group in $groups_to_delete; do
        groupdel "$group" 2>/dev/null
    done
}

remove_cpanel_cron() {
    log_info "Removing cPanel cron jobs..."
    
    # Remove all cron entries
    crontab -l | grep -v cpanel | grep -v whm | crontab -
    rm -f /etc/cron.d/cpanel*
    rm -f /etc/cron.d/whm*
    rm -f /var/spool/cron/cpanel*
    rm -f /var/spool/cron/root
}

cleanup_system() {
    log_info "Cleaning system configurations..."
    
    # Clean hosts file
    sed -i '/cpanel/d' /etc/hosts
    sed -i '/whm/d' /etc/hosts
    
    # Clean bash history
    sed -i '/cpanel/d' /root/.bash_history
    sed -i '/whm/d' /root/.bash_history
    
    # Clean log files
    find /var/log -name "*cpanel*" -exec rm -f {} \; 2>/dev/null
    find /var/log -name "*whm*" -exec rm -f {} \; 2>/dev/null
    
    # Clean temp files
    find /tmp -name "*cpanel*" -exec rm -f {} \; 2>/dev/null
    find /tmp -name "*whm*" -exec rm -f {} \; 2>/dev/null
}

verify_removal() {
    log_info "Verifying cPanel removal..."
    
    local remaining=0
    
    # Check for remaining files
    if find / -name "*cpanel*" 2>/dev/null | head -5; then
        log_warning "Found some cPanel files remaining"
        remaining=1
    fi
    
    # Check for remaining processes
    if pgrep -f cpanel > /dev/null || pgrep -f whm > /dev/null; then
        log_warning "Found cPanel processes running"
        remaining=1
    fi
    
    # Check for packages
    if (command -v dpkg && dpkg -l | grep -i cpanel) || (command -v rpm && rpm -qa | grep -i cpanel); then
        log_warning "Found cPanel packages installed"
        remaining=1
    fi
    
    if [[ $remaining -eq 0 ]]; then
        log_success "cPanel COMPLETELY REMOVED - No traces found!"
    else
        log_warning "Some traces remain - consider manual cleanup"
    fi
}

# MAIN EXECUTION
main() {
    display_header
    
    # Final warning - SIMPLIFIED
    echo -e "${RED}⚠️  DANGER: This will DESTROY all cPanel data!${NC}"
    read -p "Continue? (y/n): " confirm
    
    if [[ "$confirm" != "y" ]]; then
        log_error "Operation cancelled"
        exit 1
    fi
    
    # Backup
    read -p "Create backup? (y/n): " backup_confirm
    if [[ "$backup_confirm" == "y" ]]; then
        create_backup
    else
        log_warning "No backup created - proceeding anyway"
    fi
    
    # AGGRESSIVE REMOVAL
    log_info "Starting ULTIMATE cPanel removal..."
    
    remove_cpanel_services
    remove_cpanel_packages
    remove_cpanel_files
    remove_cpanel_users
    remove_cpanel_cron
    cleanup_system
    
    # Final verification
    verify_removal
    
    log_success "cPanel removal completed!"
    log_info "System is now clean"
    
    # Ask for reboot
    read -p "Reboot now? (y/n): " reboot_confirm
    if [[ "$reboot_confirm" == "y" ]]; then
        log_info "Rebooting system..."
        reboot
    fi
}

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "Run as root: sudo bash $0"
    exit 1
fi

# Start
main
