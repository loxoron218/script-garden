#==============================================================================
# SECTION 1: System Preparation
#==============================================================================

## Configure drive
sudo mkdir -p /mnt/sda1
sudo umount /dev/sda1
sudo mkfs.btrfs -f /dev/sda1 # Don't forget to backup your data!
sudo mount /dev/sda1 /mnt/sda1
sudo sh -c "echo 'dev/sda1 /mnt/sda1 btrfs defaults 0 2' >> /etc/fstab"
sudo systemctl daemon-reload

## Configure RAID
# sudo mkdir -p /mnt/raid
# sudo mkfs.btrfs -f -d raid1 -m raid1 /dev/sda /dev/sdb # Add more devices if you want
# sudo mount /dev/sda /mnt/raid
# sudo sh -c "echo '/dev/sda /mnt/raid btrfs defaults 0 2' >> /etc/fstab"
# sudo systemctl daemon-reload

## Configure pacman
sudo sed -i "s/#Color/Color/" /etc/pacman.conf
sudo sed -i "s/#VerbosePkgLists/VerbosePkgLists/" /etc/pacman.conf
sudo sed -i "s/#ParallelDownloads/ParallelDownloads/" /etc/pacman.conf

#==============================================================================
# SECTION 2: Package Installation and Configuration
#==============================================================================

## Install necessary applilcations
sudo pacman -Syyu --noconfirm networkmanager podman podman-compose firewalld openssh

## Install recommended applications
sudo pacman -S --noconfirm bash-completion fastfetch neovim restic powertop xorg-xset

## Configure NetworkManager
sudo systemctl enable NetworkManager.service

## Configure fastfetch
echo "fastfetch" >> ~/.bashrc
echo "alias clearfetch='clear && fastfetch'" >> ~/.bashrc

#==============================================================================
# SECTION 3: SSH Configuration
#==============================================================================

## Set port for SSH
blocked_ports=$(grep -oP '(?<=- )\d{1,5}(?=:)' "$(dirname "$0")/arch-postinstallation-nas.sh" | tr '\n' ' ')
while true; do
    random_port=$(shuf -i 1000-9999 -n 1)
    if [[ ! " ${blocked_ports} " =~ " ${random_port} " ]]; then
        break
    fi
done

## Edit SSH config
sudo sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
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
# SECTION 4: Restic Backup Configuration
#==============================================================================

## Create restic backup script
mkdir ~/server
cat >> ~/server/restic-backup.sh << EOF
export RESTIC_PASSWORD="secure_psswd"
restic backup /home/$(whoami)/server -r /mnt/sda1/Server --exclude=/home/$(whoami)/server/immich/postgres --exclude=/home/$(whoami)/server/ryot/postgres_storage --verbose
restic forget --keep-last 7 -r /mnt/sda1/Server
restic prune -r /mnt/sda1/Server
EOF
chmod +x ~/server/restic-backup.sh

# Create systemd service file
cat >> ~/restic.service << EOF
[Unit]
Description=Backup Arch User Server Directory

[Service]
ExecStart=/bin/bash /home/$(whoami)/server/restic-backup.sh
User=$(whoami)
EOF
sudo mv ~/restic.service /etc/systemd/system/restic.service 

# Create systemd timer file
sudo sh -c "cat >> /etc/systemd/system/restic.timer << EOF
[Unit]
Description=Run backup script every day at 2 AM

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF"

# Start restic
sudo mkdir -p /mnt/sda1/Server
sudo chmod -R 777 /mnt/sda1/Server
restic init -r /mnt/sda1/Server --verbose
sudo systemctl daemon-reload
sudo systemctl enable restic.timer

#==============================================================================
# SECTION 5: Create podman-compose files
#==============================================================================

## Create portainer-compose file
mkdir ~/server/portainer
cat >> ~/server/portainer-compose.yaml << EOF
services:
  portainer-ce:
    image: docker.io/portainer/portainer-ce:sts
    container_name: portainer
    volumes:
      - /run/user/1000/podman/podman.sock:/var/run/docker.sock
      - /home/$(whoami)/server/portainer:/data
    ports:
      - 8000:8000
      - 9443:9443
    restart: unless-stopped
    # privileged: true
EOF

## Create stack-compose file
cat >> ~/server/stack-compose.yaml << EOF
# ==============================
# Monitoring Stack
# ==============================
services:
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    volumes:
      - /:/rootfs
      - /var/run:/var/run
      - /sys:/sys
      - /var/lib/docker/:/var/lib/docker
      - /dev/disk/:/dev/disk
      - /run/user/1000/podman:/var/run/podman
      - /sys/fs/cgroup:/sys/fs/cgroup
    ports:
      - 8081:8080
    restart: unless-stopped
    devices:
      - /dev/kmsg
    # privileged: true

  grafana:
    image: docker.io/grafana/grafana:main
    container_name: grafana
    volumes:
      - /home/$(whoami)/server/grafana:/var/lib/grafana
    ports:
      - 3000:3000
    restart: unless-stopped

  node_exporter:
    image: docker.io/prom/node-exporter:master
    container_name: node_exporter
    volumes:
      - /:/host
    restart: unless-stopped
    command:
      - --path.rootfs=/host
    network_mode: host
    pid: host

  prometheus:
    image: docker.io/prom/prometheus:main
    container_name: prometheus
    volumes:
      - /home/$(whoami)/server/prometheus:/etc/prometheus
    ports:
      - 9090:9090
    restart: unless-stopped
    command: --config.file=/etc/prometheus/prometheus.yaml

# ==============================
# Immich Stack
# ==============================
  immich-server:
    image: ghcr.io/immich-app/immich-server:${IMMICH_VERSION:-release}
    container_name: immich_server
    volumes:
      # Do not edit the next line. If you want to change the media storage location on your system, edit the value of UPLOAD_LOCATION in the .env file
      - ${UPLOAD_LOCATION}:/usr/src/app/upload
      # - /etc/localtime:/etc/localtime:ro
    ports:
      - 2283:2283
    restart: unless-stopped
    env_file:
      - stack.env
    # extends:
        # file: hwaccel.transcoding.yaml
        # service: quicksync # set to one of [nvenc, quicksync, rkmpp, vaapi, vaapi-wsl] for accelerated transcoding
    depends_on:
      - redis
      - database
    devices:
      - /dev/dri:/dev/dri
    healthcheck:
      disable: false

  immich-machine-learning:
    # For hardware acceleration, add one of -[armnn, cuda, openvino] to the image tag.
    # Example tag: ${IMMICH_VERSION:-release}-cuda
    image: ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION:-release}-openvino
    container_name: immich_machine_learning
    volumes:
      - /home/$(whoami)/server/immich/model-cache:/cache
      - /dev/bus/usb:/dev/bus/usb
    restart: unless-stopped
    # device_cgroup_rules:
      # - c 189:* rmw
    devices:
      - /dev/dri:/dev/dri
    env_file:
      - stack.env
    # extends: # uncomment this section for hardware acceleration - see https://immich.app/docs/features/ml-hardware-acceleration
      # file: hwaccel.ml.yaml
      # service: openvino # set to one of [armnn, cuda, openvino, openvino-wsl] for accelerated inference - use the -wsl version for WSL2 where applicable
    healthcheck:
      disable: false

  database:
    image: docker.io/tensorchord/pgvecto-rs:pg14-v0.2.0@sha256:90724186f0a3517cf6914295b5ab410db9ce23190a2d9d0b9dd6463e3fa298f0
    container_name: immich_postgres
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_DB: ${DB_DATABASE_NAME}
      POSTGRES_INITDB_ARGS: --data-checksums
    volumes:
      # Do not edit the next line. If you want to change the database storage location on your system, edit the value of DB_DATA_LOCATION in the .env file
      - ${DB_DATA_LOCATION}:/var/lib/postgresql/data
    restart: unless-stopped
    command: >-
      postgres
      -c shared_preload_libraries=vectors.so
      -c 'search_path=$$user, public, vectors'
      -c logging_collector=on
      -c max_wal_size=2GB
      -c shared_buffers=512MB
      -c wal_compression=on
    healthcheck:
      test: >-
        pg_isready --dbname=$${POSTGRES_DB} --username=$${POSTGRES_USER} || exit 1;
        Chksum=$$(psql --dbname=$${POSTGRES_DB} --username=$${POSTGRES_USER} --tuples-only --no-align
        --command=SELECT COALESCE(SUM(checksum_failures), 0) FROM pg_stat_database);
        echo checksum failure count is $$Chksum;
        [ $$Chksum = 0 ] || exit 1
      interval: 5m
      # start_interval: 30s
      start_period: 5m

  redis:
    image: docker.io/redis:6.2-alpine@sha256:148bb5411c184abd288d9aaed139c98123eeb8824c5d3fce03cf721db58066d8
    container_name: immich_redis
    restart: unless-stopped
    healthcheck:
      test: redis-cli ping || exit 1

# ==============================
# Media Stack
# ==============================
  jellyfin:
    image: docker.io/jellyfin/jellyfin:unstable
    container_name: jellyfin
    # environment:
      # - JELLYFIN_PublishedServerUrl=http://example.com
    volumes:
      - /home/$(whoami)/server/jellyfin/cache:/cache:z
      - /home/$(whoami)/server/jellyfin/config:/config:z
      # - /home/$(whoami)/server/jellyfin/fonts:/usr/local/share/fonts/custom:z
      - /mnt/sda1/filme:/media/movies:z
      - /mnt/sda1/musik:/media/music:z
      - /mnt/sda1/serien:/media/tvshows:z
      - /home/$(whoami)/server/jellyfin/tmp:/tmp/jellyfin:z
    ports:
      - 8096:8096
    restart: unless-stopped
    devices:
      - /dev/dri:/dev/dri
    extra_hosts:
      - host.docker.internal:10.88.0.1
    labels:
      io.containers.autoupdate: registry
    # network_mode: host
    # security_opt:
      # - label=disable  # Only needed for container-selinux < 2.226
    # user: 1000:1000
    # userns_mode: keep-id

  makemkv:
    image: docker.io/jlesage/makemkv:latest
    container_name: makemkv
    ports:
      - 5800:5800
    volumes:
      - /home/$(whoami)/server/makemkv:/config:rw,z
      - /mnt/sda1:/storage:ro,z
      - /mnt/sda1/.downloads:/output:rw,z
    # devices:
       # - /dev/sr0
       # - /dev/sg2
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:nightly
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /home/$(whoami)/server/radarr:/config:z
      - /mnt/sda1/filme:/movies:z #optional
      - /mnt/sda1/.downloads:/downloads:z #optional
    ports:
      - 7878:7878
    restart: unless-stopped

  ryot:
    image: docker.io/ignisda/ryot:develop
    container_name: ryot
    environment:
      - TZ=Europe/Amsterdam
      - SERVER_ADMIN_ACCESS_TOKEN=ryot_token # CHANGE THIS
      - DATABASE_URL=postgres://postgres:postgres@ryot-db:5432/postgres
    ports:
      - 8000:8000
    restart: unless-stopped
    pull_policy: always

  ryot-db:
    image: docker.io/postgres:16-alpine
    container_name: ryot-db
    volumes:
      - /home/enrique/server/ryot-db:/var/lib/postgresql/data
    restart: unless-stopped
    environment:
      - TZ=Europe/Amsterdam
      - POSTGRES_DB=postgres
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=secure_psswd

  sabnzbd:
    image: lscr.io/linuxserver/sabnzbd:nightly
    container_name: sabnzbd
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /home/$(whoami)/server/sabnzbd:/config:z
      - /mnt/sda1/.downloads:/downloads:z #optional
      - /mnt/sda1/.downloads/sabnzbd:/incomplete-downloads:z #optional
    ports:
      - 8082:8080
    restart: unless-stopped

  slskd:
    image: docker.io/slskd/slskd:canary
    container_name: slskd
    environment:
      - SLSKD_REMOTE_CONFIGURATION=true
      # - SLSKD_SHARED_DIR=/music
    volumes:
      - /home/$(whoami)/server/slskd:/app:z
      - /mnt/sda1/musik:/music:z
    ports:
      - 5030:5030
      - 5031:5031
      - 50300:50300
    restart: unless-stopped
    # user: 1000:1000

# ==============================
# Server Stack (Placeholders)
# ==============================
  # duckdns:
  # traefik:

# ==============================
# Core Tools
# ==============================
  homarr:
    image: ghcr.io/homarr-labs/homarr:dev
    container_name: homarr
    environment:
      - SECRET_ENCRYPTION_KEY=homarr_token # <--- can be generated with openssl rand -hex 32
    volumes:
      - /run/user/1000/podman/podman.sock:/var/run/docker.sock:z # <--- add this line here!
      - /home/$(whoami)/server/homarr:/appdata:z
    ports:
      - 7575:7575
    restart: unless-stopped

  nextcloud:
    image: lscr.io/linuxserver/nextcloud:develop
    container_name: nextcloud
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /home/$(whoami)/server/nextcloud/config:/config:z
      - /home/$(whoami)/server/nextcloud/data:/data:z
    ports:
      - 4443:443
    restart: unless-stopped

  vaultwarden:
    image: docker.io/vaultwarden/server:testing
    container_name: vaultwarden
    # environment:
      # - DOMAIN=https://vw.domain.tld
    volumes:
      - /home/$(whoami)/server/vaultwarden:/data:z
    ports:
      - 8080:80
    restart: unless-stopped
EOF

#==============================================================================
# SECTION 6: Configure Podman containers
#==============================================================================

## Homarr configuration
homarr_token=$(openssl rand -hex 32)
sed -i "s/homarr_token/${homarr_token}/" ~/server/stack-compose.yaml

## Immich configuration
mkdir ~/server/immich
cat >> ~/server/immich/.env << EOF
# You can find documentation for all the supported env variables at https://immich.app/docs/install/environment-variables

# The location where your uploaded files are stored
UPLOAD_LOCATION=/home/$(whoami)/server/immich/library
# The location where your database files are stored
DB_DATA_LOCATION=/home/$(whoami)/server/immich/postgres

# To set a timezone, uncomment the next line and change Etc/U TC to a TZ identifier from this list: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List
# TZ=Europe/Berlin

# The Immich version to use. You can pin this to a specific version like "v1.71.0"
IMMICH_VERSION=release

# Connection secret for postgres. You should change it to a random password
# Please use only the characters A-Za-z0-9, without special characters or spaces
DB_PASSWORD=secure_psswd

# The values below this line do not need to be changed
###################################################################################
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
EOF

## Prometheus configuration
mkdir ~/server/prometheus
cat >> ~/server/prometheus/prometheus.yaml << EOF
---
global:
  scrape_interval: 15s  # By default, scrape targets every 15 seconds.

  # Attach these labels to any time series or alerts when communicating with
  # external systems (federation, remote storage, Alertmanager).
  # external_labels:
  #  monitor: codelab-monitor

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label job=<job_name> to any timeseries scraped from this config.
  - job_name: prometheus
    # Override the global default and scrape targets from this job every 5 seconds.
    scrape_interval: 5s
    static_configs:
      - targets: [localhost:9090]

# Example job for node_exporter
  - job_name: node_exporter
    static_configs:
      - targets: [node_exporter:9100]

# Example job for cadvisor
  - job_name: cadvisor
    static_configs:
      - targets: [cadvisor:8082]
EOF

## Ryot configuration
ryot_token=$(openssl rand -hex 10)
sed -i "s/ryot_token/${ryot_token}/" ~/server/stack-compose.yaml

## Folder creation
mkdir -p ~/server/grafana/plugins
mkdir -p /mnt/sda1/filme /mnt/sda1/musik /mnt/sda1/serien

## Password creation
while true; do
    read -s -p "Enter a secure password for your apps: " secure_psswd
    echo
    read -s -p "Confirm your secure password: " secure_psswd_confirm
    if [[ "$secure_psswd" == "$secure_psswd_confirm" ]]; then
        echo "Password confirmed."
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done
sed -i "s/secure_psswd/${secure_psswd}/" ~/server/restic-backup.sh ~/server/immich/.env ~/server/stack-compose.yaml

#==============================================================================
# SECTION 7: Install Podman containers
#==============================================================================

## Start Podman
systemctl enable --user --now podman.socket

## Configure Podman auto-updates
systemctl enable --user --now podman-auto-update.timer
systemctl enable --user --now podman-auto-update.service

## Run portainer-compose file
podman compose -f ~/server/portainer-compose.yaml up -d

#==============================================================================
# SECTION 8: Perform post-installation configuration
#==============================================================================

## slskd configuration
sed -i "/^# soulseek:/,/^#   connection:/s/^# \{0,1\}//" ~/server/slskd/slskd.yml
sed -i "s/username: ~$/username: $(whoami)/" ~/server/slskd/slskd.yml
sed -i "s/password: ~$/password: ${secure_psswd}/" ~/server/slskd/slskd.yml
podman restart slskd

#==============================================================================
# SECTION 9: Cleanup
#==============================================================================

## Remove unnecessary files
sudo pacman -Scc --noconfirm
rm -rf ~/.cache/go-build
rm -rf ~/.config/go

## Run powertop
sudo powertop --calibrate
sudo powertop --auto-tune

## Remember SSH port
echo -e "Your SSH port is: $random_port"