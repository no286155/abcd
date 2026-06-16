# #Downloads
# curl -s -o login.sh -L "https://raw.githubusercontent.com/JohnnyNetsec/github-vm/main/mac/login.sh"
# #disable spotlight indexing
# sudo mdutil -i off -a
# #Create new account
# sudo dscl . -create /Users/runneradmin
# sudo dscl . -create /Users/runneradmin UserShell /bin/bash
# sudo dscl . -create /Users/runneradmin RealName Runner_Admin
# sudo dscl . -create /Users/runneradmin UniqueID 1001
# sudo dscl . -create /Users/runneradmin PrimaryGroupID 80
# sudo dscl . -create /Users/runneradmin NFSHomeDirectory /Users/runneradmin
# sudo dscl . -passwd /Users/runneradmin P@ssw0rd!
# sudo dscl . -passwd /Users/runneradmin P@ssw0rd!
# sudo createhomedir -c -u runneradmin > /dev/null
# sudo dscl . -append /Groups/admin GroupMembership runneradmin
# echo "runner ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers.d/runner
# sudo sysadminctl -addUser myuser -admin
# sudo sed -i '' 's/%admin		ALL = (ALL) ALL/%admin		ALL = (ALL) NOPASSWD: ALL/g' /etc/sudoers
# sudo -v
# #Enable VNC
# sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -allowAccessFor -allUsers -privs -all
# sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes 
# echo runnerrdp | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt
# #Start VNC/reset changes
# sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console
# sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate
# # Install localtunnel via npm

# # # Install Localtunnel (instead of ngrok)
# # brew install localtunnel

# # # Start Localtunnel to expose VNC on a secure external URL
# # lt --port 5900 --subdomain vnc-access &

# # echo "VNC server running and accessible via LocalTunnel. Connect using the provided URL."
# # curl https://loca.lt/mytunnelpassword
# # # Get public IP address using curl
# # IP=$(curl -s https://api.ipify.org)

# # echo "Your public IP address is: $IP"
# brew install cloudflared
# sudo cloudflared service install $1

# #install ngrok
# brew install ngrok

# #configure ngrok and start it
# ngrok authtoken $2
# ngrok tcp 5900 &


#!/bin/bash
# setup_display.sh
# Run early in your GitHub Actions workflow to create a virtual display,
# then expose it via VNC + cloudflared tunnel.
# Usage: bash setup_display.sh <vnc_password> <tunnel_token>
 
set -euo pipefail
 
VNC_PASSWORD="abcdef"
TUNNEL_TOKEN="${1:?missing cloudflared tunnel token}"
 
echo "==> Compiling virtual display helper..."
cat << 'SWIFT' > /tmp/virtual_display.swift
import Foundation
import CoreGraphics
 
typealias CGVirtualDisplayRef = OpaquePointer
 
@_silgen_name("CGVirtualDisplayCreate")
func CGVirtualDisplayCreate(
    _ width: UInt32, _ height: UInt32, _ ppi: UInt32,
    _ name: CFString?, _ serialNumber: UInt32,
    _ productID: UInt32, _ vendorID: UInt32
) -> CGVirtualDisplayRef?
 
guard let display = CGVirtualDisplayCreate(
    1920, 1080, 96,
    "CI-VirtualDisplay" as CFString,
    0x0001, 0x1234, 0x5678
) else {
    fputs("ERROR: CGVirtualDisplayCreate failed\n", stderr)
    exit(1)
}
 
print("Virtual display created (1920x1080)")
dispatchMain()
SWIFT
 
swiftc /tmp/virtual_display.swift -o /tmp/virtual_display
echo "==> Starting virtual display..."
nohup /tmp/virtual_display > /tmp/virtual_display.log 2>&1 &
DISPLAY_PID=$!
echo "Display PID: $DISPLAY_PID"
sleep 3
 
echo "==> Verifying display..."
/usr/libexec/screencapture -x /tmp/display_test.png 2>&1 && echo "screencapture OK" || echo "screencapture still failing (may need a moment)"
 
echo "==> Enabling VNC..."
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
    -activate -configure -access -on \
    -clientopts -setvnclegacy -vnclegacy yes \
    -clientopts -setvncpw -vncpw "${VNC_PASSWORD}" \
    -restart -agent -console
 
echo "==> Starting cloudflared tunnel..."
brew install cloudflared 2>/dev/null || true
nohup cloudflared tunnel --no-autoupdate run --token "${TUNNEL_TOKEN}" > /tmp/cloudflared.log 2>&1 &
 
echo "==> Done. Connect via VNC with password: ${VNC_PASSWORD}"
