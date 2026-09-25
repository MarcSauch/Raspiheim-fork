FROM debian@sha256:da496358bd6934d2bd6a563a33176a2e50eff5490c54b4ac6fb051b69fef4071


#Install Prereqs
RUN chmod 1777 /tmp \
&&  dpkg --add-architecture armhf \
&&  apt update -y \
&&  apt upgrade -y \
&&  apt install -y  apt-utils ca-certificates knockd unzip wget curl gpg systemd \
                    libc6 libc6:armhf libatomic1 libatomic1:armhf libcurl3t64-gnutls:armhf libpulse-dev libpulse-dev:armhf libpulse0 libpulse0:armhf libmonoboehm-2.0-1 libmonoboehm-2.0-1:armhf

#Install Box86-Repo

RUN wget --inet4-only https://itai-nelken.github.io/weekly-box86-debs/debian/box86.list -O /etc/apt/sources.list.d/box86.list \
&&  wget --inet4-only -qO- https://itai-nelken.github.io/weekly-box86-debs/debian/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box86-debs-archive-keyring.gpg \
&&  apt update \
&&  apt install box86:armhf -y


#Install Box64-Repo
RUN wget --inet4-only https://ryanfortner.github.io/box64-debs/box64.list -O /etc/apt/sources.list.d/box64.list \
&&  wget --inet4-only -qO- https://ryanfortner.github.io/box64-debs/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box64-debs-archive-keyring.gpg \
&&  apt update \
&&  apt install -y box64-rpi4arm64

#Configure box64 for Valheim-Server
RUN echo "" >> /etc/box64.box64rc \
&&  echo "[valheim_server.x86_64]" >> /etc/box64.box64rc \
&&  echo "BOX64_DYNAREC_STRONGMEM=2" >> /etc/box64.box64rc \
&&  echo "BOX64_DYNAREC_BLEEDING_EDGE=0" >> /etc/box64.box64rc \
&&  echo "BOX64_DYNAREC_BIGBLOCK=3" >> /etc/box64.box64rc

# Install Steam
RUN mkdir   /steamcmd \
&&  cd      /steamcmd \
&&  curl --fail --silent --show-error --location "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - \
&&  cd      /steamcmd \
&&  for attempt in 1 2 3 4 5; do \
        box86 ./linux32/steamcmd -tcp +quit && break; \
        [ "$attempt" -lt 5 ] || exit 1; \
        sleep 5; \
    done \
&&  mkdir -p /valheim /data \
&&  chmod -R a+rwX /steamcmd /valheim /data

# Install required library and scripts
COPY ./add /scripts/
RUN chmod +x /scripts/valheim.sh

# Setting Environmental Variables
ENV SERVER_NAME=Raspiheim \
    SERVER_PASS=Raspipass \
    WORLD_NAME=Raspiworld \
    SAVE_DIR=/data \
    PUBLIC=disabled \
    UPDATE=enabled \
    PAUSE=disabled \
    SAVE_INTERVAL=1800 \
    CROSSPLAY=disabled \
    BOX86=default \
    BOX64=default \
    HOME=/steamcmd

EXPOSE 2456/udp 2457/udp

ENTRYPOINT ["/scripts/valheim.sh"]
