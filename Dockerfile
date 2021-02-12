FROM python:3.8-slim-buster

RUN echo "Check python version"
RUN python --version

# install open-jre
# RUN apk add --no-cache openjdk8-jre su-exec
RUN apt-get update && apt-get install -y software-properties-common
RUN add-apt-repository ppa:openjdk-r/ppa
RUN apt-get update && apt-get install -y \
    openjdk-8-jdk

ENV VERSION 7.6.2
ENV DOWNLOAD_URL https://artifacts.elastic.co/downloads/logstash
ENV TARBALL "${DOWNLOAD_URL}/logstash-oss-${VERSION}.tar.gz"
ENV TARBALL_ASC "${DOWNLOAD_URL}/logstash-oss-${VERSION}.tar.gz.asc"
ENV TARBALL_SHA "c425a9748964ef38fc58f67778cd88fc367df91087362353cfee316e54528e4a23407e1fc53d628008fd4c829b427061758112f10e7805cec88c0a1f0a966d2a"
ENV GPG_KEY "46095ACC8548582C1A2699A9D27D666CD88E42B4"

# Provide a non-root user to run the process.
RUN addgroup --gid 1000 logstash && \
  adduser -u 1000 -G logstash \
  -h /usr/share/logstash -H -D \
  logstash

# RUN apk add --no-cache libzmq bash
RUN apt-get install -y \
    libzmq \
    bash
# RUN apk add --no-cache -t .build-deps wget ca-certificates gnupg openssl \
RUN apt-get install -y wget ca-certificates gnupg openssl \
  && set -ex \
  && cd /tmp \
  && wget --progress=bar:force -O logstash.tar.gz "$TARBALL"; \
  if [ "$TARBALL_SHA" ]; then \
  echo "$TARBALL_SHA *logstash.tar.gz" | sha512sum -c -; \
  fi; \
  \
  if [ "$TARBALL_ASC" ]; then \
  wget --progress=bar:force -O logstash.tar.gz.asc "$TARBALL_ASC"; \
  export GNUPGHOME="$(mktemp -d)"; \
  ( gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
  || gpg --keyserver pgp.mit.edu --recv-keys "$GPG_KEY" \
  || gpg --keyserver keyserver.pgp.com --recv-keys "$GPG_KEY" ); \
  gpg --batch --verify logstash.tar.gz.asc logstash.tar.gz; \
  rm -rf "$GNUPGHOME" logstash.tar.gz.asc || true; \
  fi; \
  tar -xzf logstash.tar.gz \
  && mv logstash-$VERSION /usr/share/logstash \
  && chown --recursive logstash:logstash /usr/share/logstash/ \
  && chown -R logstash:root /usr/share/logstash \
  && chmod -R g=u /usr/share/logstash \
  && find /usr/share/logstash -type d -exec chmod g+s {} \; \
  && ln -s /usr/share/logstash /opt/logstash \
  && rm -rf /tmp/* \
  && apt-get purge wget ca-certificates gnupg openssl

# RUN apk add --no-cache libc6-compat
RUN apt-get install -y libc6-compat

# install build-tools
# RUN apk add --update gcc g++
RUN apt-get -y update && apt-get -y install gcc g++

# install openssl
# RUN apk add --update openssl && \
#     rm -rf /var/cache/apk/*

RUN apt-get install -y \
    openssl \
 && rm -rf /var/lib/apt/lists/*

# install curl
# RUN apk --no-cache add curl
RUN apt-get install -y curl

ENV PATH /usr/share/logstash/bin:/sbin:$PATH
ENV LS_SETTINGS_DIR /usr/share/logstash/config
ENV LANG='en_US.UTF-8' LC_ALL='en_US.UTF-8'

RUN set -ex; \
  if [ -f "$LS_SETTINGS_DIR/log4j2.properties" ]; then \
  cp "$LS_SETTINGS_DIR/log4j2.properties" "$LS_SETTINGS_DIR/log4j2.properties.dist"; \
  truncate -s 0 "$LS_SETTINGS_DIR/log4j2.properties"; \
  fi

# Install & Verify logstash plugins
RUN logstash-plugin install logstash-codec-csv
RUN logstash-plugin list

WORKDIR /usr/share/logstash

# Copy Logstash pre-config folder
COPY config/logstash /usr/share/logstash/config/
COPY config/pipeline/default.conf /usr/share/logstash/pipeline/logstash.conf
RUN chown --recursive logstash:root config/ pipeline/

# Copy Python App folder
COPY app /app
WORKDIR /app
RUN pip install -U pip
RUN pip install -r requirements.txt
RUN chown --recursive logstash:root .

USER 1000

EXPOSE 9600 5044 8080 8089

CMD ["python", "-u", "/app/app.py"]