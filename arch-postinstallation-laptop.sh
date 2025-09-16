#==============================================================================
# SECTION 1: Repository preparation
#==============================================================================

## Configure pacman
sudo sed -i "s/#Color/Color/" /etc/pacman.conf
sudo sed -i "s/#VerbosePkgLists/VerbosePkgLists/" /etc/pacman.conf
sudo sed -i "s/#ParallelDownloads/ParallelDownloads/" /etc/pacman.conf

## Set up Chaotic AUR
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U --noconfirm https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst
sudo pacman -U --noconfirm https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zstrm -rf ~/.config/nvim/.git^

## Add repositories
sudo sh -c "cat >> /etc/pacman.conf << EOF

[gnome-unstable]
Include = /etc/pacman.d/mirrorlist

[kde-unstable]
Include = /etc/pacman.d/mirrorlist

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF"

## Install paru
sudo pacman -Syyu --noconfirm git
git clone https://aur.archlinux.org/paru.git
(cd paru && makepkg -si --noconfirm)
sudo rm -rf ~/paru

## Configure paru
sudo sed -i "s/^#\(BottomUp\)/\1/" /etc/paru.conf
sudo sed -i "s/^#\(CombinedUpgrade\)/\1/" /etc/paru.conf
sudo sed -i "s/^#\(UpgradeMenu\)/\1/" /etc/paru.conf

#==============================================================================
# SECTION 2: Package Installation
#==============================================================================

## Install GUI applications from official repository
paru -S audacity bleachbit dconf-editor evince ghostty gnome-calculator gnome-control-center gnome-disk-utility gnome-software gnome-text-editor gnome-tweaks libreoffice-fresh-de mission-center nautilus picard soundconverter strawberry telegram-desktop vlc-plugin-ffmpeg

## Install other applications from official repository
paru -S --noconfirm adw-gtk-theme bash-completion fastfetch firefox-ublock-origin ffmpegthumbnailer gnome-shell-extension-appindicator gvfs-mtp kdegraphics-thumbnailers neovim noto-fonts-emoji power-profiles-daemon powertop ttf-liberation xdg-user-dirs xorg-xhost

## Install GUI applications from AUR
paru -S --noconfirm extension-manager flatseal localsend-bin nuclear-player-bin vscodium-bin wasistlos

## Install other applications from AUR
paru -S --noconfirm adwaita-qt5 brother-hll2350dw dcraw-thumbnailer ffmpeg-audio-thumbnailer firefox-arkenfox-autoconfig firefox-extension-bitwarden firefox-extension-istilldontcareaboutcookies-bin gnome-shell-extension-bing-wallpaper gnome-shell-extension-blur-my-shell nautilus-open-any-terminal

## Install Flatpak applications
flatpak update --user
flatpak install --user -y adw-gtk3-dark bottles

#==============================================================================
# SECTION 3: System Configuration
#==============================================================================

## Configure Graphical User Interface
paru -S --noconfirm gdm
gsettings set org.gnome.mutter experimental-features "['autoclose-xwayland' , 'kms-modifiers' , 'scale-monitor-framebuffer' , 'variable-refresh-rate' , 'xwayland-native-scaling']"
sudo systemctl enable gdm.service
sudo systemctl set-default graphical.target

## Configure Plymouth
paru -S --noconfirm plymouth
sudo sed -i "s/^HOOKS=(/HOOKS=(plymouth /" /etc/mkinitcpio.conf
sudo plymouth-set-default-theme -R bgrt
sudo sed -i "s/\(rw\)/\1 quiet splash/" /boot/loader/entries/*.conf

## Configure network
paru -S --noconfirm network-manager-applet
sudo systemctl enable NetworkManager.service

## Configure Bluetooth
sudo sed -i "s/#AutoEnable=true/AutoEnable=false/" /etc/bluetooth/main.conf
sudo systemctl enable bluetooth.service

## Configure printer
sudo systemctl enable cups.service
sudo lpadmin -p HLL2350DW -v lpd://192.168.178.67/BINARY_P1 -E
sudo lpoptions -d HLL2350DW # Manual configuaration still needed

#==============================================================================
# SECTION 5: Delete when self hosting
#==============================================================================

## Install apps that can be replaced by self hosting
paru -S --noconfirm jre-openjdk par2cmdline-turbo
paru -S --noconfirm 7zip firefox-extension-keepassxc-browser keepassxc makemkv nicotine+ python-orjson radarr sabnzbd stirling-pdf syncthing syncthing-gtk

## Configure KeePassXC
mkdir ~/.local/share/applications
cp /usr/share/applications/org.keepassxc.KeePassXC.desktop ~/.local/share/applications
sed -i "/^StartupNotify=true$/d" ~/.local/share/applications/org.keepassxc.KeePassXC.desktop

## Configure Radarr
sudo curl -o /usr/share/pixmaps/Radarr.svg https://raw.githubusercontent.com/Radarr/Radarr/refs/heads/develop/Logo/Radarr.svg
cat > ~/.local/share/applications/Radarr.desktop << 'EOF'
[Desktop Entry]
Name=Radarr
Exec=/usr/lib/radarr/bin/Radarr -browser
Terminal=False
Type=Application
Icon=/usr/share/pixmaps/Radarr.svg
EOF

## Configure SABnzbd
sudo curl -o /usr/share/pixmaps/logo-arrow.svg https://raw.githubusercontent.com/sabnzbd/sabnzbd/refs/heads/develop/icons/logo-arrow.svg
cp /usr/lib/sabnzbd/linux/sabnzbd.desktop ~/.local/share/applications
sed -i "s|^Exec=.*|Exec=/usr/lib/sabnzbd/SABnzbd.py --browser 1|" ~/.local/share/applications/sabnzbd.desktop
sed -i "s|^Icon=.*|Icon=/usr/share/pixmaps/logo-arrow.svg|" ~/.local/share/applications/sabnzbd.desktop
xdg-mime default sabnzbd.desktop application/x-nzb

## Configure Stirling-PDF
mkdir -p /home/$(whoami)/configs
cat > /home/$(whoami)/configs/custom_settings.yml << EOF
server:
  host: 0.0.0.0
  port: 3000
EOF
sudo curl -o /usr/share/pixmaps/stirling.svg https://raw.githubusercontent.com/Stirling-Tools/Stirling-PDF/refs/heads/main/docs/stirling.svg
cat > ~/.local/share/applications/Stirling-PDF.desktop << EOF
[Desktop Entry]
Name=Stirling-PDF
Exec=bash -c "nohup java -jar /usr/share/java/stirling-pdf.jar & sleep 15 && xdg-open http://localhost:3000" &
Terminal=False
Type=Application
Icon=/usr/share/pixmaps/stirling.svg
EOF

#==============================================================================
# SECTION 6: Package Configuration
#==============================================================================

## Hide unwanted desktop icons
cp /usr/share/applications/{avahi-discover,bssh,bvnc,cmake-gui,codium,cups,libreoffice-base,libreoffice-calc,libreoffice-draw,libreoffice-impress,libreoffice-math,libreoffice-writer,lstopo,nm-connection-editor,nvim,nvtop,org.gnome.Extensions,qv4l2,qvidcap}.desktop ~/.local/share/applications/
sed -i \
    -e '/^NoDisplay=/d' \
    -e '/^\[Desktop Entry\]/a NoDisplay=true' \
    ~/.local/share/applications/{avahi-discover,bssh,bvnc,cmake-gui,codium,cups,libreoffice-base,libreoffice-calc,libreoffice-draw,libreoffice-impress,libreoffice-math,libreoffice-writer,lstopo,nm-connection-editor,nvim,nvtop,org.gnome.Extensions,qv4l2,qvidcap}.desktop

## Add BleachBit as root
cp /usr/share/applications/org.bleachbit.BleachBit.desktop ~/.local/share/applications/org.bleachbit.BleachBit-sudo.desktop
sed -i "s/BleachBit/BleachBit (as root)/" ~/.local/share/applications/org.bleachbit.BleachBit-sudo.desktop
sed -i "s|^Exec=.*|Exec=pkexec bleachbit|" ~/.local/share/applications/org.bleachbit.BleachBit-sudo.desktop
sed -i "s|^StartupWMClass=.*|StartupWMClass=pkexec bleachbit|" ~/.local/share/applications/org.bleachbit.BleachBit-sudo.desktop

## Configure Bottles
flatpak override --user com.usebottles.bottles --filesystem=host
flatpak override --user com.usebottles.bottles --filesystem=xdg-data/applications

## Configure fastfetch
fastfetch --gen-config
sed -i '/"battery",/c\ \ \ \ {\n\ \ \ \ \ \ "type": "battery",\n\ \ \ \ \ \ "key": "Battery"\n\ \ \ \ },' /home/arch/.config/fastfetch/config.jsonc
echo fastfetch >> ~/.bashrc
echo alias "clearfetch='clear && fastfetch'" >> ~/.bashrc

## Configure Ghostty
mkdir ~/.config/ghostty
cat > ~/.config/ghostty/config << 'EOF'
clipboard-paste-bracketed-safe = true
clipboard-paste-protection = false
font-family = Noto Sans Mono
font-size = 11
theme = Adwaita Dark
EOF

## Configure Neovim
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

## Configure Syncthing
sudo systemctl enable syncthing.service

## Configure VSCodium
cp /usr/share/applications/codium-wayland.desktop ~/.local/share/applications/
sed -i "s/VSCodium - Wayland/VSCodium/" ~/.local/share/applications/codium-wayland.desktop
xdg-mime default org.gnome.Nautilus.desktop inode/directory

## Configure other apps
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal ghostty
gsettings set org.gnome.desktop.privacy remember-recent-files false
gsettings set org.gnome.nautilus.preferences show-image-thumbnails always

#==============================================================================
# SECTION 7: Cleanup
#==============================================================================

## Use powertop
sudo powertop --calibrate
sudo powertop --auto-tune
paru -Rns --noconfirm powertop

## Remove unnecessary files
paru -Scc --noconfirm
orphans=$(pacman -Qdtq)
if [[ -n $orphans ]]; then
  paru -Rns --noconfirm $orphans
else
  echo "No orphaned packages to remove."
fi
sudo rm -rf ~/.cache
sudo rm -rf ~/.cargo
sudo rm -rf ~/.npm
sudo rm -rf ~/.rustup
paru -Syyu --noconfirm
