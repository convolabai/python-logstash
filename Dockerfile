FROM python:3.8-slim

RUN echo "Check python version"
RUN python --version

# Install OS packages
RUN apt-get update && apt-get -y upgrade
  
WORKDIR /opt
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        curl \
        gnupg \
        openssl \
        bash \
        vim \
    && curl \
        -L \
        -o openjdk.tar.gz \
        https://download.java.net/java/GA/jdk11/13/GPL/openjdk-11.0.1_linux-x64_bin.tar.gz \
    && mkdir jdk \
    && tar zxf openjdk.tar.gz -C jdk --strip-components=1 \
    && rm -rf openjdk.tar.gz \
    && apt-get -y --purge autoremove curl \
    && ln -sf /opt/jdk/bin/* /usr/local/bin/ \
    && rm -rf /var/lib/apt/lists/* \
    && java  --version \
    && javac --version \
    && jlink --version

# Set Logstash Version
ENV VERSION 7.6.2

# Provide a non-root user to run the process.
RUN addgroup --gid 1000 logstash && \
  adduser -u 1000 -G logstash \
  -h /usr/share/logstash -H -D \
  logstash

# Install Logstash
RUN wget https://artifacts.elastic.co/downloads/logstash/logstash-${VERSION}.deb
RUN dpkg -i logstash-${VERSION}.deb

ENV PATH /usr/share/logstash/bin:/sbin:$PATH
ENV LS_SETTINGS_DIR /usr/share/logstash/config
ENV LANG='en_US.UTF-8' LC_ALL='en_US.UTF-8'

RUN set -ex; \
  if [ -f "$LS_SETTINGS_DIR/log4j2.properties" ]; then \
  cp "$LS_SETTINGS_DIR/log4j2.properties" "$LS_SETTINGS_DIR/log4j2.properties.dist"; \
  truncate -s 0 "$LS_SETTINGS_DIR/log4j2.properties"; \
  fi

# Install & Verify Logstash plugins
RUN logstash-plugin install logstash-codec-csv
RUN logstash-plugin list

# Copy Logstash pre-config folder

WORKDIR /usr/share/logstash

COPY config/logstash /usr/share/logstash/config/
COPY config/pipeline/default.conf /usr/share/logstash/pipeline/logstash.conf
RUN chown --recursive logstash:root config/ pipeline/ data/
RUN ln -s /usr/share/logstash /opt/logstash

# Copy Python App folder
COPY app /app
WORKDIR /app
RUN pip install -r requirements.txt
RUN chown --recursive logstash:root .
RUN chmod 777 /opt/logstash/pipeline

USER logstash

EXPOSE 9600 5044 8080 8089

CMD ["python", "-u", "/app/app.py"]