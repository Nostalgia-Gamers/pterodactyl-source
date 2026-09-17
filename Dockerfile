FROM debian:trixie-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    curl ca-certificates \
 && curl -sSL https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz | tar xz \
 && mv rcon-0.10.3-amd64_linux/rcon /usr/local/bin/rcon

# ------- Final image -------
FROM debian:trixie-slim

LABEL author="Custom" maintainer="you@example.com"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN useradd -m -d /home/container -s /bin/bash container

# Install only what HLDS/SteamCMD actually needs — single layer, fully cleaned
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    # Base tools
    bash curl ca-certificates tar tini locales patchelf \
    # 32-bit libs (SteamCMD + HLDS + AMXX)
    libc6:i386 \
    lib32gcc-s1 \
    lib32stdc++6 \
    lib32z1 \
    libcurl4:i386 \
    libcurl3-gnutls:i386 \
    libtinfo6:i386 \
    libncurses6:i386 \
    libgoogle-perftools4t64:i386 \
    # Database libs (required by AMXX/Metamod plugins)
    # MariaDB's client is plain C. MySQL 8's libmysqlclient needs GCC 13's
    # libstdc++, and hlds_run puts HLDS's bundled old libstdc++ first on
    # LD_LIBRARY_PATH, so it fails to dlopen inside the game server.
    libmariadb3:i386 \
    libpq5:i386 \
    # 64-bit libs
    libstdc++6 \
    libtinfo6 \
    libncursesw6 \
    libfontconfig1 \
    libnss-wrapper \
    gettext-base \
 && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
 && locale-gen \
 && ln -s /usr/lib/i386-linux-gnu/libmariadb.so.3 /usr/lib/i386-linux-gnu/libmysqlclient.so.21 \
 && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /var/log/* /tmp/* /usr/share/doc/* /usr/share/man/*

COPY --from=builder /usr/local/bin/rcon /usr/local/bin/rcon
COPY ./entrypoint.sh /entrypoint.sh

USER        container
ENV         HOME=/home/container
WORKDIR     /home/container

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/bin/bash", "/entrypoint.sh"]
