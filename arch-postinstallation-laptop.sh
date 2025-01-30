#==============================================================================
# SECTION 1: Repository preparation
#==============================================================================

## Configure pacman
sudo sed -i 's/#Color/Color/' /etc/pacman.conf
sudo sed -i 's/#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sudo sed -i 's/#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

## Set up Chaotic AUR
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

## Add repositories
sudo sh -c 'cat >> /etc/pacman.conf << EOF

[gnome-unstable]
Include = /etc/pacman.d/mirrorlist

[kde-unstable]
Include = /etc/pacman.d/mirrorlist

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF'

## Install yay
sudo pacman -Syyu --noconfirm git
git clone https://aur.archlinux.org/yay.git
(cd yay && makepkg -si --noconfirm)
sudo rm -rf ~/yay

#==============================================================================
# SECTION 2: Package Installation
#==============================================================================

## Install GUI applications from official repository
sudo pacman -S audacity bleachbit dconf-editor evince ghostty gnome-calculator gnome-control-center gnome-disk-utility gnome-software gnome-text-editor gnome-tweaks libreoffice-fresh mission-center nautilus pdfarranger picard soundconverter strawberry telegram-desktop vlc

## Install other applications from official repository
sudo pacman -S --noconfirm adw-gtk-theme bash-completion fastfetch firefox-ublock-origin ffmpegthumbnailer gnome-shell-extension-appindicator gvfs-mtp kdegraphics-thumbnailers power-profiles-daemon powertop ttf-liberation xdg-user-dirs xorg-xhost xorg-xset

## Install GUI applications from AUR
yay -S extension-manager flatseal localsend-bin nuclear-player-bin vscodium-bin whatsapp-for-linux

## Install other applications from AUR
yay -S --noconfirm brother-hll2350dw dcraw-thumbnailer ffmpeg-audio-thumbnailer firefox-arkenfox-autoconfig firefox-extension-bitwarden gnome-shell-extension-bing-wallpaper gnome-shell-extension-blur-my-shell nautilus-open-any-terminal

## Install Flatpak applications
flatpak update
flatpak install -y adw-gtk3-dark winezgui

#==============================================================================
# SECTION 3: System Configuration
#==============================================================================

## Configure Graphical User Interface
yay -S --noconfirm gdm
gsettings set org.gnome.mutter experimental-features "['autoclose-xwayland' , 'kms-modifiers' , 'scale-monitor-framebuffer' , 'variable-refresh-rate' , 'xwayland-native-scaling']"
sudo systemctl enable gdm.service
sudo systemctl set-default graphical.target

## Configure Plymouth
# yay -S --noconfirm plymouth
# sudo sed -i 's/^HOOKS=(/HOOKS=(plymouth /' /etc/mkinitcpio.conf
# sudo plymouth-set-default-theme -R bgrt
# sudo sed -i 's/$/ quiet splash/' /boot/loader/entries/*.conf

## Configure network
yay -S --noconfirm network-manager-applet
sudo systemctl enable NetworkManager.service

## Configure Bluetooth
sudo sed -i 's/#AutoEnable=true/AutoEnable=false/' /etc/bluetooth/main.conf
sudo systemctl enable bluetooth.service

## Configure printer
sudo systemctl enable cups.service
sudo lpadmin -p HLL2350DW -v lpd://192.168.178.67/BINARY_P1 -E
sudo lpoptions -d HLL2350DW # Manual configuaration still needed

#==============================================================================
# SECTION 5: Delete when self hosting
#==============================================================================

## Install apps that can be replaced by self hosting
yay -S --noconfirm 7zip firefox-extension-keepassxc-browser keepassxc nicotine+ par2cmdline-turbo python-orjson radarr sabnzbd syncthing syncthing-gtk

## Configure Radarr
sudo curl -o /usr/share/pixmaps/Radarr.svg https://raw.githubusercontent.com/Radarr/Radarr/refs/heads/develop/Logo/Radarr.svg
sudo sh -c 'cat >> ~/.local/share/applications/Radarr.desktop << EOF
[Desktop Entry]
Name=Radarr
Exec=/usr/lib/radarr/bin/Radarr -browser
Terminal=False
Type=Application
Icon=/usr/share/pixmaps/Radarr.svg
EOF'

## Configure SABnzbd
sudo curl -o /usr/share/pixmaps/logo-arrow.svg https://raw.githubusercontent.com/sabnzbd/sabnzbd/refs/heads/develop/icons/logo-arrow.svg
sudo cp /usr/lib/sabnzbd/linux/sabnzbd.desktop ~/.local/share/applications
sudo sed -i 's|^Exec=.*|Exec=/usr/lib/sabnzbd/SABnzbd.py --browser 1|' ~/.local/share/applications/sabnzbd.desktop
sudo sed -i 's|^Icon=.*|Icon=/usr/share/pixmaps/logo-arrow.svg|' ~/.local/share/applications/sabnzbd.desktop


#==============================================================================
# SECTION 6: Package Configuration
#==============================================================================

## Hide unwanted desktop icons
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/avahi-discover.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/bssh.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/bvnc.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/bvnc.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/codium.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/cups.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/libreoffice-base.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/libreoffice-calc.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/libreoffice-draw.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/libreoffice-impress.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/libreoffice-math.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/libreoffice-writer.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/nm-connection-editor.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/org.gnome.Extensions.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/qv4l2.desktop
echo "NoDisplay=true" | sudo tee ~/.local/share/applications/qvidcap.desktop

## Change name of VSCodium
cp /usr/share/applications/codium-wayland.desktop ~/.local/share/applications/
sudo sed -i 's/VSCodium - Wayland/VSCodium/' ~/.local/share/applications/codium-wayland.desktop

## Add BleachBit as root
sudo cp /usr/share/applications/org.bleachbit.BleachBit.desktop ~/.local/share/applications/org.bleachbit.BleachBit-sudo.desktop
sudo sed -i 's/BleachBit/BleachBit (as root)/' ~/.local/share/applications/org.bleachbit.BleachBit-sudo.desktop
sudo sed -i 's|^Exec=.*|Exec=pkexec bleachbit|' ~/.local/share/applications/org.bleachbit.BleachBit-sudo.desktop
sudo sed -i 's|^StartupWMClass=.*|StartupWMClass=pkexec bleachbit|' ~/.local/share/applications/org.bleachbit.BleachBit-sudo.desktop

## Configure fastfetch
fastfetch --gen-config
echo "fastfetch" >> ~/.bashrc
echo "alias clearfetch='clear && fastfetch'" >> ~/.bashrc
source ~/.bashrc

## Configure Ghostty
cat >> ~/.config/ghostty/config << EOF
clipboard-paste-bracketed-safe = true
clipboard-paste-protection = false
font-family = Noto Sans Mono
font-size = 11
theme = Adwaita Dark
EOF ## Manual configuration reload still needed

## Configure KeePassXC
echo "StartupNotify=true" | sudo tee ~/.local/share/applications/org.keepassxc.KeePassXC.desktop

## Configure other apps
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal ghostty
gsettings set org.gnome.desktop.privacy remember-recent-files false
gsettings set org.gnome.nautilus.preferences show-image-thumbnails 'always'

#==============================================================================
# SECTION 7: Cleanup
#==============================================================================

## Use powertop
sudo powertop --calibrate
sudo powertop --auto-tune
yay -Rnsu --noconfirm powertop xorg-xset

## Remove unnecessary files
yay -Yc --noconfirm
sudo pacman -Scc --noconfirm
sudo rm -rf ~/.cache/
sudo rm -rf ~/.cargo/
sudo rm -rf ~/.npm/
yay -Syyu --noconfirm