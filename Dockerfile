FROM debian:trixie-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    curl ca-certificates \
 && curl -sSL https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz | tar xz \
 && mv rcon-0.10.3-amd64_linux/rcon /usr/local/bin/rcon

# Extract real libmysqlclient.so.21 (i386) from Ubuntu 24.04 LTS (Debian ships no i386 build)
FROM ubuntu:noble AS mysql-donor

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends libmysqlclient21:i386

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
 && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /var/log/* /tmp/* /usr/share/doc/* /usr/share/man/*

COPY --from=builder /usr/local/bin/rcon /usr/local/bin/rcon
COPY --from=mysql-donor /usr/lib/i386-linux-gnu/libmysqlclient.so.21* /usr/lib/i386-linux-gnu/
COPY ./entrypoint.sh /entrypoint.sh

USER        container
ENV         HOME=/home/container
WORKDIR     /home/container

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/bin/bash", "/entrypoint.sh"]
