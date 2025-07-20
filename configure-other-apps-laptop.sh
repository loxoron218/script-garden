# ============================================
# 1. Theme & Application Configuration
# ============================================

# ----------------------------
# Alacritty Theme Configuration
# ----------------------------
mkdir -p ~/.config/alacritty/themes
git clone https://github.com/alacritty/alacritty-theme ~/.config/alacritty/themes
cat > ~/.alacritty.toml << EOF
[general]
import = [
    "~/.config/alacritty/themes/themes/gnome_terminal.toml"
]
EOF

# ============================================
# 2. Desktop Icons for Applications
# ============================================

# ----------------------------
# Gemini Desktop Icon
# ----------------------------
sudo curl -o  /usr/share/pixmaps/gemini.svg https://uxwing.com/wp-content/themes/uxwing/download/brands-and-social-media/google-gemini-icon.svg
cat <<EOF > ~/.local/share/applications/gemini.desktop
[Desktop Entry]
Name=Gemini CLI
Comment=Access Gemini space using Ghostty terminal
Exec=ghostty -e gemini
Icon=/usr/share/pixmaps/gemini.svg
Terminal=false
Type=Application
Categories=Utility;Network;
StartupNotify=true
EOF

# ----------------------------
# Jackett Desktop Icon
# ----------------------------
sudo curl -o /usr/share/pixmaps/jacket_medium.svg https://raw.githubusercontent.com/Jackett/Jackett/95384a92ee9d86301743b10d33dd72d3846372da/src/Jackett.Common/Content/jacket_medium.png
sudo sh -c 'cat > /usr/share/applications/Jackett.desktop << EOF
[Desktop Entry]
Name=Jackett
Exec=sh -c "/usr/lib/jackett/jackett & sleep 10 && xdg-open http://localhost:9117"
Terminal=False
Type=Application
Icon=/usr/share/pixmaps/jacket_medium.svg
EOF'

# ----------------------------
# Radarr Desktop Icon
# ----------------------------
sudo curl -o /usr/share/pixmaps/Radarr.svg https://raw.githubusercontent.com/Radarr/Radarr/refs/heads/develop/Logo/Radarr.svg
sudo sh -c 'cat > /usr/share/applications/Radarr.desktop << EOF
[Desktop Entry]
Name=Radarr
Exec=/usr/lib/radarr/bin/Radarr -browser
Terminal=False
Type=Application
Icon=/usr/share/pixmaps/Radarr.svg
EOF'

# ----------------------------
# SABnzbd Desktop Icon
# ----------------------------
sudo curl -o /usr/share/pixmaps/logo-arrow.svg https://raw.githubusercontent.com/sabnzbd/sabnzbd/refs/heads/develop/icons/logo-arrow.svg
sudo cp /usr/lib/sabnzbd/linux/sabnzbd.desktop /usr/share/applications/
sudo sh -c 'cat >> /usr/share/applications/sabnzbd.desktop << EOF
Exec=/usr/lib/sabnzbd/SABnzbd.py --browser 1
Icon=/usr/share/pixmaps/logo-arrow.svg
EOF'

# ============================================
# 3. Repository Configuration
# ============================================
sudo pacman -Syyu
sudo pacman -S reflector
sudo reflector -c DE -l 10 -p https --save /etc/pacman.d/mirrorlist
sudo pacman -Rnsu reflector