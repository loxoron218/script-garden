#==============================================================================
# SECTION 1: System Preparation
#==============================================================================

## Configure drive
sudo mkdir /mnt/sda1
sudo umount /dev/sda1
sudo mkfs.btrfs -f /dev/sda1 # Don't forget to backup your data!
sudo mount /dev/sda1 /mnt/sda1
sudo sh -c 'echo "/dev/sda1 /mnt/sda1 btrfs defaults 0 2" >> /etc/fstab'
sudo systemctl daemon-reload

## Configure RAID
# sudo mkdir /mnt/raid
# sudo mkfs.btrfs -f -d raid1 -m raid1 /dev/sda /dev/sdb # Add more devices if you want
# sudo mount /dev/sda /mnt/raid
# sudo sh -c 'echo "/dev/sda /mnt/raid btrfs defaults 0 2" >> /etc/fstab'
# sudo systemctl daemon-reload

## Configure pacman
sudo sed -i "s/#Color/Color/" /etc/pacman.conf
sudo sed -i "s/#VerbosePkgLists/VerbosePkgLists/" /etc/pacman.conf
sudo sed -i "s/#ParallelDownloads/ParallelDownloads/" /etc/pacman.conf

## Add yay
sudo pacman -Syyu --noconfirm git
git clone https://aur.archlinux.org/yay.git
(cd yay && makepkg -si --noconfirm)
sudo rm -rf ~/yay

#==============================================================================
# SECTION 2: Package Installation and Configuration
#==============================================================================

## Install necessary applilcations
yay -S --noconfirm dhcpcd docker docker-compose firewalld openssh

## Install recommended applications
yay -S --noconfirm bash-completion btop fastfetch nano powertop xorg-xset

## Install recommended AUR applications
yay -S --noconfirm lazydocker-bin

## Configure dhcpcd
sudo systemctl enable dhcpcd.service

## Configure fastfetch
fastfetch --gen-config
echo "fastfetch" >> ~/.bashrc
echo "alias clearfetch='clear && fastfetch'" >> ~/.bashrc

#==============================================================================
# SECTION 3: SSH Configuration
#==============================================================================

## Block container ports for SSH
blocked_ports=$(grep -oP '(?<=- )\d{1,5}(?=:)' "$(dirname "$0")/archserver.sh" | tr '\n' ' ')

## Set port for SSH
while true; do
    random_port=$(shuf -i 1000-9999 -n 1)
    
    # Check if the generated port is in the blocked list
    if [[ ! " ${blocked_ports} " =~ " ${random_port} " ]]; then
        break
    fi
done

## Edit SSH config
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i "s/#Port 22/Port ${random_port}/" /etc/ssh/sshd_config
sudo systemctl enable sshd.service

## Configure firewalld
sudo systemctl enable firewalld.service
sudo systemctl start firewalld.service
sudo firewall-cmd --zone=public --add-port=${random_port}/tcp --permanent
for port in $blocked_ports; do
    sudo firewall-cmd --zone=public --add-port=${port}/tcp --permanent
done

sudo firewall-cmd --reload

#==============================================================================
# SECTION 4: Immich preparation
#==============================================================================

## Set password for immich database
mkdir -p ~/server/immich
while true; do
    read -s -p "Enter your Immich database password: " DB_PASSWORD
    echo
    read -s -p "Confirm your Immich database password: " DB_PASSWORD_CONFIRM
    echo

    if [[ "$DB_PASSWORD" == "$DB_PASSWORD_CONFIRM" ]]; then
        echo "Immich database password confirmed."
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

## Create environment file
cat >> ~/server/immich/.env << EOF
# You can find documentation for all the supported env variables at https://immich.app/docs/install/environment-variables

# The location where your uploaded files are stored
UPLOAD_LOCATION=/home/archuser/server/immich/library
# The location where your database files are stored
DB_DATA_LOCATION=/home/archuser/server/immich/postgres

# To set a timezone, uncomment the next line and change Etc/U TC to a TZ identifier from this list: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List
# TZ=Europe/Berlin

# The Immich version to use. You can pin this to a specific version like "v1.71.0"
IMMICH_VERSION=release

# Connection secret for postgres. You should change it to a random password
# Please use only the characters `A-Za-z0-9`, without special characters or spaces
DB_PASSWORD=${DB_PASSWORD}

# The values below this line do not need to be changed
###################################################################################
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
EOF

## Download hardware acceleration files
curl -L -o ~/server/immich/hwaccel.transcoding.yml https://github.com/immich-app/immich/releases/latest/download/hwaccel.transcoding.yml
curl -L -o ~/server/immich/hwaccel.ml.yml https://github.com/immich-app/immich/releases/latest/download/hwaccel.ml.yml
sudo chown -R $(whoami) ~/server

#==============================================================================
# SECTION 5: Create docker-compose file
#==============================================================================

## Create docker-compose file
cat >> ~/server/immich/docker-compose.yml << 'EOF'
services:
  duckdns:
    image: lscr.io/linuxserver/duckdns:latest
    container_name: duckdns
    environment:
      - PUID=1000 # Optional
      - PGID=1000 # Optional
      - TZ=Europe/Berlin # Optional
      - SUBDOMAINS=duck_domain
      - TOKEN=duck_token
      - UPDATE_IP=both # Optional
      - LOG_FILE=false # Optional
    volumes:
      - /home/archuser/server/duckdns/config:/config # Optional
    restart: unless-stopped
    network_mode: host # Optional

  duplicati:
    image: lscr.io/linuxserver/duplicati:development
    container_name: duplicati
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
      - SETTINGS_ENCRYPTION_KEY=
      - CLI_ARGS= # Optional
      - DUPLICATI__WEBSERVICE_PASSWORD=secure_psswd
    volumes:
      - /home/archuser/server/duplicati/config:/config
      - /mnt/sda1/server:/backups
      - /:/source
    ports:
      - 8200:8200
    restart: unless-stopped

  homarr: 
    image: ghcr.io/ajnart/homarr:latest
    container_name: homarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # Optional, only if you want docker integration
      - /home/archuser/server/homarr/configs:/app/data/configs
      - /home/archuser/server/homarr/icons:/app/public/icons
      - /home/archuser/server/homarr/data:/data
    ports:
      - 7575:7575
    restart: unless-stopped

  immich-server:
    image: ghcr.io/immich-app/immich-server:${IMMICH_VERSION:-release}
    container_name: immich_server
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    volumes:
      # Do not edit the next line. If you want to change the media storage location on your system, edit the value of UPLOAD_LOCATION in the .env file
      - ${UPLOAD_LOCATION}:/usr/src/app/upload
      - /etc/localtime:/etc/localtime:ro
    ports:
      - 2283:2283
    restart: unless-stopped
    extends:
      file: hwaccel.transcoding.yml
      service: quicksync # Set to one of [nvenc, quicksync, rkmpp, vaapi, vaapi-wsl] for accelerated transcoding
    env_file:
      - .env
    depends_on:
      - redis
      - database
    healthcheck:
      disable: false

  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION:-release}-openvino
    container_name: immich_machine_learning
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    volumes:
      - /home/archuser/server/immich/model-cache:/cache
    restart: unless-stopped
    extends:
      file: hwaccel.ml.yml
      service: openvino # set to one of [armnn, cuda, openvino, openvino-wsl] for accelerated inference - use the `-wsl` version for WSL2 where applicable
    env_file:
      - .env
    healthcheck:
      disable: false

  database:
    image: docker.io/tensorchord/pgvecto-rs:pg14-v0.2.0@sha256:90724186f0a3517cf6914295b5ab410db9ce23190a2d9d0b9dd6463e3fa298f0
    container_name: immich_postgres
    environment: # PUID and PGID are missing
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_DB: ${DB_DATABASE_NAME}
      POSTGRES_INITDB_ARGS: '--data-checksums'
    volumes:
    # Do not edit the next line. If you want to change the database storage location on your system, edit the value of DB_DATA_LOCATION in the .env file
      - ${DB_DATA_LOCATION}:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: >-
        pg_isready --dbname="$${POSTGRES_DB}" --username="$${POSTGRES_USER}" || exit 1;
        Chksum="$$(psql --dbname="$${POSTGRES_DB}" --username="$${POSTGRES_USER}" --tuples-only --no-align
        --command='SELECT COALESCE(SUM(checksum_failures), 0) FROM pg_stat_database')";
        echo "checksum failure count is $$Chksum";
        [ "$$Chksum" = '0' ] || exit 1
      interval: 5m
      start_interval: 30s
      start_period: 5m
    command: >-
      postgres
      -c shared_preload_libraries=vectors.so
      -c 'search_path="$$user", public, vectors'
      -c logging_collector=on
      -c max_wal_size=2GB
      -c shared_buffers=512MB
      -c wal_compression=on

  redis:
    image: docker.io/redis:6.2-alpine@sha256:eaba718fecd1196d88533de7ba49bf903ad33664a92debb24660a922ecd9cac8
    container_name: immich_redis
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    restart: unless-stopped
    healthcheck:
      test: redis-cli ping || exit 1

  jellyfin:
    image: lscr.io/linuxserver/jellyfin:nightly
    container_name: jellyfin
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
      # - JELLYFIN_PublishedServerUrl=http://192.168.0.5 # Optional
    volumes:
      - /home/archuser/server/jellyfin/library:/config
      - /mnt/sda1/Filme:/data/movies
      - /mnt/sda1/Serien:/data/tvshows
      - /mnt/sda1/Musik:/data/music
    ports:
      - 8096:8096
      - 8920:8920 # Optional
      - 7359:7359/udp # Optional
      - 1900:1900/udp # Optional
    restart: unless-stopped

  makemkv:
    image: jlesage/makemkv
    container_name: makemkv
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    volumes:
      - /home/archuser/server/makemkv/appdata/makemkv:/config:rw
      - /mnt/sda1:/storage:rw
      # - /mnt/sda1:/output:rw
    ports:
      - 5800:5800
    restart: unless-stopped
    # devices: # Optional
      # - /dev/sr0:/dev/sr0
      # - /dev/sg2:/dev/sg2

  maloja:
    image: krateng/maloja
    container_name: maloja
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
      - MALOJA_DATA_DIRECTORY=/mljdata
      - MALOJA_FORCE_PASSWORD=secure_psswd
    volumes:
      - /home/archuser/server/maloja:/mljdata
    ports:
      - 42010:42010
    restart: unless-stopped

  nextcloud:
    image: lscr.io/linuxserver/nextcloud:develop
    container_name: nextcloud
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    volumes:
      - /home/archuser/server/nextcloud/config:/config
      - /home/archuser/server/nextcloud/data:/data
    ports:
      - 444:443
      - 83:80
    restart: unless-stopped

  nginx-proxy-manager:
    image: docker.io/jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    volumes:
      - /home/archuser/server/nginx-proxy-manager/data:/data
      - /home/archuser/server/nginx-proxy-manager/letsencrypt:/etc/letsencrypt
    ports:
      - 80:80
      - 81:81
      - 443:443
    restart: unless-stopped

  nicotine-plus:
    image: ghcr.io/fletchto99/nicotine-plus-docker:latest
    container_name: nicotine-plus
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
      - PASSWORD=secure_psswd
    volumes:
      - /home/archuser/server/nicotine-plus/data:/config
      - /mnt/sda1:/data/downloads
      - /mnt/sda1/nicotine-plus:/data/incomplete_downloads
      - /home/archuser/server/nicotine-plus/shared:/data/shared #optional
    ports:
      - 6080:6080
      - 2234-2239:2234-2239
    restart: unless-stopped
    security_opt:
      - seccomp:unconfined #optional

  radarr:
    image: lscr.io/linuxserver/radarr:nightly
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    volumes:
      - /home/archuser/server/radarr/data:/config
      - /mnt/sda1/Filme:/movies # Optional
      - /mnt/sda1:/downloads # Optional
    ports:
      - 7878:7878
    restart: unless-stopped

  ryot:
    image: ignisda/ryot:develop # or ghcr.io/ignisda/ryot:v7
    container_name: ryot
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
      - DATABASE_URL=postgres://postgres:postgres@ryot-db:5432/postgres
      - SERVER_ADMIN_ACCESS_TOKEN=ryot_token # CHANGE THIS
    ports:
      - 8000:8000
    restart: unless-stopped
    pull_policy: always

  ryot-db:
    image: postgres:16-alpine # at-least version 15 is required
    container_name: ryot-db
    environment:
      - TZ=Europe/Berlin
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_USER=postgres
      - POSTGRES_DB=postgres
    volumes:
      - /home/archuser/server/ryot/postgres_storage:/var/lib/postgresql/data
    restart: unless-stopped

  sabnzbd:
    image: lscr.io/linuxserver/sabnzbd:nightly
    container_name: sabnzbd
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    volumes:
      - /home/archuser/server/sabnzbd/config:/config
      - /mnt/sda1:/downloads # Optional
      - /mnt/sda1/sabnzbd:/incomplete-downloads # Optional
    ports:
      - 8080:8080
    restart: unless-stopped

  vaultwarden:
    image: vaultwarden/server:testing
    container_name: vaultwarden
    environment: # Optional
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
      # DOMAIN: "https://vw.domain.tld"
    volumes:
      - /home/archuser/server/vaultwarden/vw-data/:/data/
    ports:
      - 82:80
    restart: unless-stopped

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
EOF

#==============================================================================
# SECTION 6: Configure Docker containers
#==============================================================================

## Set username
sed -i "s/archuser/$(whoami)/" ~/server/immich/.env ~/server/immich/docker-compose.yml

## Set Ryot random token
ryot_token=$(openssl rand -hex 10)
sudo sed -i "s/ryot_token/${ryot_token}/" ~/server/immich/docker-compose.yml

## Set secure app password
while true; do
    read -s -p "Enter a secure password for your apps: " secure_psswd
    echo
    read -s -p "Confirm your secure password: " secure_psswd_confirm
    echo

    if [[ "$secure_psswd" == "$secure_psswd_confirm" ]]; then
        echo "Password confirmed."
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done
sudo sed -i "s/secure_psswd/${secure_psswd}/" ~/server/immich/docker-compose.yml


## Add Duck DNS credentials
read -p "Enter your Duck DNS domain: " duck_domain
sudo sed -i "s/duck_domain/${duck_domain}/" ~/server/immich/docker-compose.yml
echo
read -p "Enter your Duck DNS token: " duck_token
sudo sed -i "s/duck_token/${duck_token}/" ~/server/immich/docker-compose.yml
echo

#==============================================================================
# SECTION 7: Intall Docker containers
#==============================================================================

## Start Docker
sudo systemctl enable docker.service
sudo systemctl start docker.service

## Run docker-compose file
sudo docker compose -f ~/server/immich/docker-compose.yml up -d

#==============================================================================
# SECTION 8: Cleanup
#==============================================================================

## Remove unnecessary files
yay -Yc --noconfirm
yay -Scc --noconfirm
sudo rm -rf ~/.cache/go-build
sudo rm -rf ~/.config/go

## Update system
yay -Syyu --noconfirm
sudo powertop --calibrate
sudo powertop --auto-tune

## Remember SSH port
echo -e "Your SSH port is: $random_port"