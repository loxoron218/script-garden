## Configure Duck DNS with cronie
read -p "Enter your Duck DNS domain: " duck_domain
read -p "Enter your Duck DNS token: " duck_token
echo
mkdir -p ~/duckdns
sudo chown -R $(whoami) ~/duckdns
echo "echo url=\"https://www.duckdns.org/update?domains=${duck_domain}&token=${duck_token}&verbose=true\" | curl -k -o ~/duckdns/duck.log -K -" > ~/duckdns/duck.sh
chmod 700 ~/duckdns/duck.sh
echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1" | crontab -
sudo systemctl enable cronie.service
~/duckdns/duck.sh

## Setup server backup with rsync
cat >> /home/$(whoami)/server/backup.sh << EOF
# Run rsync to sync files to a temporary backup directory
rsync -av --delete /home/$(whoami)/server/ /tmp/server-backup/

# Create a zip file from the synced files with the current timestamp
zip -r -P "secure_psswd""/mnt/sda1/server-backup-$(date +'%Y%m%d%H%M%S').zip" /tmp/server-backup/

# Clean up temporary files
rm -rf /tmp/server-backup

# Keep only the 7 most recent backups, remove older ones
find /mnt/sda1 -name "server-backup-*.zip" | sort | head -n -7 | xargs rm -f
EOF
chmod +x /home/$(whoami)/backup.sh
(crontab -l; echo "0 2 * * * /home/$(whoami)/backup.sh") | crontab -

## Configure Vaultwarden Web
sudo sed -i 's/# WEB_VAULT_FOLDER=\/usr\/share\/webapps\/vaultwarden-web/WEB_VAULT_FOLDER=\/usr\/share\/webapps\/vaultwarden-web/' /etc/vaultwarden.env
sudo sed -i 's/WEB_VAULT_ENABLED=false/WEB_VAULT_ENABLED=true/' /etc/vaultwarden.env