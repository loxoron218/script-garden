# ============================================
# 1. Theme & Application Configuration
# ============================================

# ----------------------------
# Alacritty Theme Configuration
# ----------------------------
mkdir -p ~/.config/alacritty/themes
git clone https://github.com/alacritty/alacritty-theme ~/.config/alacritty/themes
cat > ~/.alacritty.toml <<EOF
[general]
import = [
    "~/.config/alacritty/themes/themes/gnome_terminal.toml"
]
EOF

# ----------------------------
# Ghostty Theme Configuration
# ----------------------------
echo 'theme = Adwaita Dark' >> ~/.config/ghostty/config

# ============================================
# 2. Desktop Icons for Applications
# ============================================

# ----------------------------
# Jackett Desktop Icon
# ----------------------------
sudo curl -o /usr/share/pixmaps/jacket_medium.svg https://raw.githubusercontent.com/Jackett/Jackett/95384a92ee9d86301743b10d33dd72d3846372da/src/Jackett.Common/Content/jacket_medium.png
sudo sh -c 'echo "[Desktop Entry]" >> ~/.local/share/applications/Jackett.desktop'
sudo sh -c 'echo "Name=Jackett" >> ~/.local/share/applications/Jackett.desktop'
sudo sh -c 'echo "Exec=sh -c \"/usr/lib/jackett/jackett & sleep 10 && xdg-open http://localhost:9117\"" >> ~/.local/share/applications/Jackett.desktop'
sudo sh -c 'echo "Terminal=False" >> ~/.local/share/applications/Jackett.desktop'
sudo sh -c 'echo "Type=Application" >> ~/.local/share/applications/Jackett.desktop'
sudo sh -c 'echo "Icon=/usr/share/pixmaps/jacket_medium.svg" >> ~/.local/share/applications/Jackett.desktop'

# ----------------------------
# Radarr Desktop Icon
# ----------------------------
sudo curl -o /usr/share/pixmaps/Radarr.svg https://raw.githubusercontent.com/Radarr/Radarr/refs/heads/develop/Logo/Radarr.svg
sudo sh -c 'echo "[Desktop Entry]" >> ~/.local/share/applications/Radarr.desktop'
sudo sh -c 'echo "Name=Radarr" >> ~/.local/share/applications/Radarr.desktop'
sudo sh -c 'echo "Exec=/usr/lib/radarr/bin/Radarr -browser" >> ~/.local/share/applications/Radarr.desktop'
sudo sh -c 'echo "Terminal=False" >> ~/.local/share/applications/Radarr.desktop'
sudo sh -c 'echo "Type=Application" >> ~/.local/share/applications/Radarr.desktop'
sudo sh -c 'echo "Icon=/usr/share/pixmaps/Radarr.svg" >> ~/.local/share/applications/Radarr.desktop'

# ----------------------------
# SABnzbd Desktop Icon
# ----------------------------
sudo curl -o /usr/share/pixmaps/logo-arrow.svg https://raw.githubusercontent.com/sabnzbd/sabnzbd/refs/heads/develop/icons/logo-arrow.svg
sudo cp /usr/lib/sabnzbd/linux/sabnzbd.desktop ~/.local/share/applications/
sudo sed -i 's|^Exec=.*|Exec=/usr/lib/sabnzbd/SABnzbd.py --browser 1|' ~/.local/share/applications/sabnzbd.desktop
sudo sed -i 's|^Icon=.*|Icon=/usr/share/pixmaps/logo-arrow.svg|' ~/.local/share/applications/sabnzbd.desktop

# ============================================
# 3. Repository Configuration
# ============================================
sudo pacman -Syyu
sudo pacman -S reflector
sudo reflector -c DE -l 10 -p https --save /etc/pacman.d/mirrorlist
sudo pacman -Rnsu reflector