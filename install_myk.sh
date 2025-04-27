#!/bin/bash

# ------------------------------------------------------------
# 🧩 MYK Node Auto-Installer for Ubuntu LTS
# ------------------------------------------------------------

# Set default password and network variables
default_password="ict01@Unigroup"
server_ip=$(ip route get 1 | awk '{print $7; exit}')

print_step() {
    echo ""
    echo "------------------------------------------------------------"
    echo "$1"
    echo "------------------------------------------------------------"
}

clear

# ============================================================
# PHASE 1: SYSTEM PREPARATION (as root)
# ============================================================

print_step "Starting MYK Node Setup"

### Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   print_step "❌ This script must be run as root. Try: sudo ./install_myk.sh"
   exit 1
fi

# ============================================================
# PHASE 2: CONFIGURING HOSTNAME AND NETWORK SETTINGS
# ============================================================

print_step "Configuring Hostname and Network Settings"

# Prompt for base hostname
read -rp "🔤 Enter the base hostname for this node (e.g., myk-dns): " BASE_HOSTNAME

# Append domain to form full hostname
FULL_HOSTNAME="${BASE_HOSTNAME}.myk.local"
print_step "🧩 Setting hostname to '$FULL_HOSTNAME'..."
hostnamectl set-hostname "$FULL_HOSTNAME"

# Set Timezone
print_step "🌐 Setting timezone to Asia/Kuala_Lumpur..."
timedatectl set-timezone Asia/Kuala_Lumpur
sleep 3  # Pause for 3 seconds
clear  # Clear screen after the pause

# Prompt for the last octet of the IP address
read -rp "📡 Enter the last octet of the IP address (e.g., 24 for 10.9.19.24): " LAST_OCTET
sleep 3  # Pause for 3 seconds
clear  # Clear screen after the pause

print_step "📍 Using provided IP last octet: $LAST_OCTET"
sleep 3  # Pause for 3 seconds
clear  # Clear screen after the pause

# Rebuild /etc/hosts
print_step "🛠️ Replacing /etc/hosts..."
cat <<EOF > /etc/hosts
127.0.0.1 localhost
127.0.1.${LAST_OCTET} ${BASE_HOSTNAME}
10.9.19.${LAST_OCTET} ${FULL_HOSTNAME} ${BASE_HOSTNAME}

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

print_step "✅ /etc/hosts updated:"
cat /etc/hosts

sleep 3  # Pause for 3 seconds
clear  # Clear screen after the pause

# Disable cloud-init network config
print_step "📛 Disabling cloud-init network config..."
cat <<EOF > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
network: {config: disabled}
EOF

print_step "✅ Cloud-init network config disabled in 99-disable-network-config.cfg"
sleep 3  # Pause for 3 seconds
clear  # Clear screen after the pause

# Detect network adapter
print_step "🌐 Detecting primary network adapter..."
ADAPTER_ID=$(ip -o link show | awk -F': ' '!/lo|docker/ {print $2; exit}')
print_step "✅ Detected network adapter: $ADAPTER_ID"
sleep 3  # Pause for 3 seconds
clear  # Clear screen after the pause

# Replace netplan config
print_step "🧼 Clearing existing netplan configs..."
cd /etc/netplan/
rm -f ./*

print_step "📝 Writing new static IP config to 00-installer-config.yaml..."
cat <<EOF > /etc/netplan/00-installer-config.yaml
network:
  version: 2
  ethernets:
    ${ADAPTER_ID}:
      dhcp4: false
      addresses:
        - 10.9.19.${LAST_OCTET}/24
      nameservers:
        addresses:
          - 10.9.19.200
          - 10.9.19.210
          - 8.8.8.8
          - 8.8.4.4
      routes:
        - to: 0.0.0.0/0
          via: 10.9.19.80
EOF

sleep 3  # Pause for 3 seconds
clear  # Clear screen after the pause

# Configure legacy /etc/network/interfaces
print_step "🧾 Writing /etc/network/interfaces for interface $ADAPTER_ID..."
cat <<EOF > /etc/network/interfaces
auto ${ADAPTER_ID}
iface ${ADAPTER_ID} inet static
    address 10.9.19.${LAST_OCTET}
    netmask 255.255.255.0
    gateway 10.9.19.80
    dns-nameservers 10.9.19.200 10.9.19.210 8.8.8.8 8.8.4.4
EOF

print_step "✅ /etc/network/interfaces written with static config for $ADAPTER_ID"
sleep 3  # Pause for 3 seconds
clear  # Clear screen after the pause

# ============================================================
# PHASE 3: INSTALLATION OF SOFTWARE PACKAGES
# ============================================================

print_step "Installing Essential Software Packages"

# Install Cockpit
print_step "🔧 Installing Cockpit..."
sudo apt update -y
sudo apt install cockpit -y
print_step "🖱️ Enabling and starting Cockpit service..."
sudo systemctl enable --now cockpit.socket
print_step "✅ Cockpit installed and running. Access it via: https://<your-server-ip>:9090"

sleep 3  # Pause for 3 seconds
clear  # Clear screen after the pause

# Install Netdata
print_step "🌐 Downloading Netdata installer script..."
wget -q https://get.netdata.cloud/kickstart.sh -O ./kickstart.sh
print_step "⚙️ Running Netdata installer..."
sudo bash ./kickstart.sh --yes

# Cleanup after installation
print_step "🧹 Deleting installer script..."
rm -f ./kickstart.sh
print_step "✅ Netdata installation complete."

sleep 3  # Pause for 3 seconds
clear  # Clear screen after the pause

# Install Docker and Docker Compose
print_step "🔧 Installing Docker..."
sudo apt update -y
sudo apt install docker.io -y
print_step "🖱️ Adding user to docker group..."
sudo usermod -aG docker $USER
print_step "⬇️ Downloading Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.17.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
print_step "⚙️ Making Docker Compose executable..."
sudo chmod +x /usr/local/bin/docker-compose
print_step "✅ Docker and Docker Compose installed successfully."

sleep 3  # Pause for 3 seconds
clear  # Clear screen after the pause

# Install Webmin
print_step "🌐 Adding Webmin GPG key..."
wget -q http://www.webmin.com/jcameron-key.asc -O- | sudo apt-key add -
print_step "📦 Adding Webmin repository..."
sudo sh -c 'echo "deb https://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list'
print_step "🔄 Updating package list..."
sudo apt-get update -y
print_step "🔧 Installing Webmin..."
sudo apt-get -y install webmin
print_step "✅ Webmin installed successfully. Access it via: https://<your-server-ip>:10000"

sleep 3  # Pause for 3 seconds
clear  # Clear screen after the pause

# ============================================================
# PHASE 4: FINAL SYSTEM UPDATE AND CLEANUP
# ============================================================

print_step "Final System Update and Cleanup"

# Update and upgrade system packages
print_step "🔄 Updating and upgrading system packages..."
sudo apt update -y && sudo apt upgrade -y

# Check for and install any missing dependencies
print_step "🔧 Checking and installing missing dependencies..."
sudo apt-get install -f -y

# Clean up unnecessary packages
print_step "🧹 Removing unnecessary packages..."
sudo apt autoremove -y

# Apply netplan configuration
print_step "✅ System update, cleanup, and network configuration complete."
sleep 3  # Pause for 3 seconds
clear  # Clear screen after the pause

# ============================================================
# PHASE 5: FINAL SHUTDOWN
# ============================================================

print_step "Shutdown"

print_step "⚠️ System is shutting down. Please create a snapshot before rebooting this server back up."
sleep 5  # Optional pause to let the message be seen
clear  # Clear screen before shutdown
shutdown now
