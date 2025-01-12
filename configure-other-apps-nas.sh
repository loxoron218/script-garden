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
sudo mkdir /mnt/sda1/server # Change directory if you are using RAID
echo "rsync -avh --delete --exclude='~/server/immich/postgres' ~/ /mnt/sda1/server" > ~/server/server_backup.sh
chmod 700 ~/server/server_backup.sh
sudo chown -R $(whoami) /mnt/sda1 # Change directory if you are using RAID
sudo chown -R $(whoami) ~/
(crontab -l 2>/dev/null; echo "0 3 * * * ~/server/server_backup.sh") | crontab -
~/server/server_backup.sh

## Configure Vaultwarden Web
sudo sed -i 's/# WEB_VAULT_FOLDER=\/usr\/share\/webapps\/vaultwarden-web/WEB_VAULT_FOLDER=\/usr\/share\/webapps\/vaultwarden-web/' /etc/vaultwarden.env
sudo sed -i 's/WEB_VAULT_ENABLED=false/WEB_VAULT_ENABLED=true/' /etc/vaultwarden.env
