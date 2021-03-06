FROM circleci/python:3.7.5


# Switch to the root user while we do our changes
USER root

# Install GStreamer and other required Debian packages
RUN apt-get update \
  && apt-get install -y \
    wget \
    dumb-init \
    graphviz-dev \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-pulseaudio \
    libasound2-dev \
    python-dev \
    python-gst-1.0 \
    python3-gst-1.0 \
    avahi-daemon \
    avahi-discover \
    libnss-mdns \
  && rm -rf /var/lib/apt/lists/*

# Make python3-gst-1.0 available to non-Debian Python 3.7 installation
RUN ln -s /usr/lib/python3/dist-packages/gi /usr/local/lib/python3.7/site-packages/gi

# Install libspotify-dev from apt.mopidy.com
RUN wget -q -O - https://apt.mopidy.com/mopidy.gpg \
  | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn apt-key add - \
  && wget -q -O /etc/apt/sources.list.d/mopidy.list https://apt.mopidy.com/buster.list \
  && apt-get update \
  && apt-get install -y libspotify-dev \
  && rm -rf /var/lib/apt/lists/*

# Clone Iris from the repository and install in development mode.
# This allows a binding at "/iris" to map to your local folder for development, rather than
# installing using pip.
RUN git clone https://github.com/jaedb/Iris.git /iris \
 && cd /iris \
 && python3.7 setup.py develop \
 && mkdir -p /var/lib/mopidy/.config \
 && ln -s /config /var/lib/mopidy/.config/mopidy \
 # Allow mopidy user to run system commands (restart, local scan, etc)
 && echo "mopidy ALL=NOPASSWD: /iris/mopidy_iris/system.sh" >> /etc/sudoers

# Install additional Python dependencies
RUN python3.7 -m pip install --no-cache \
  tox \
  mopidy-mpd \
  mopidy-spotify \
  mopidy-local \
  git+https://github.com/tehkillerbee/mopidy-tidal.git@master \
  Mopidy-Subidy \
  Mopidy-SoundCloud \
  Mopidy-Muse

# Start helper script.
COPY docker/entrypoint.sh /entrypoint.sh

# Default configuration.
COPY docker/mopidy.example.conf /config/mopidy.conf

# Copy the pulse-client configuratrion.
COPY docker/pulse-client.conf /etc/pulse/client.conf

# Add version info to image
COPY VERSION /

COPY docker/init.sh /init.sh

# Allows any user to run mopidy, but runs by default as a randomly generated UID/GID.
RUN useradd -ms /bin/bash mopidy
ENV HOME=/var/lib/mopidy
RUN set -ex \
 && usermod -G audio,sudo mopidy \
 && mkdir /var/lib/mopidy/local \
 && chown mopidy:audio -R $HOME /entrypoint.sh /iris \
 && chmod go+rwx -R $HOME /entrypoint.sh /iris \
 && echo "1" >> /IS_CONTAINER

RUN wget -P / https://github.com/badaix/snapcast/releases/download/v0.19.0/snapserver_0.19.0-1_amd64.deb \
    && dpkg -i /snapserver_0.19.0-1_amd64.deb \
    && apt-get -f install \
    && rm /snapserver_0.19.0-1_amd64.deb \
    && rm /etc/default/snapserver \
    && ln -s /config/snapserver /etc/default/snapserver \
    && rm /etc/snapserver.conf \
    && ln -s /config/snapserver.conf /etc/snapserver.conf

# Runs as mopidy user by default.
USER mopidy:audio

VOLUME ["/var/lib/mopidy/local"]

EXPOSE 6600 6680 1704 1705 5555/udp

ENTRYPOINT ["/usr/bin/dumb-init", "/entrypoint.sh"]

CMD ["/init.sh"]
