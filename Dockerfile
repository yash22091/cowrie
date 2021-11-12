FROM alpine:3.14
#
# Include dist
ADD dist/ /root/dist/
#
# Get and install dependencies & packages
RUN apk -U add \
             bash \
             build-base \
             git \
             gmp-dev \
             libcap \
             libffi-dev \
             mpc1-dev \
             mpfr-dev \
             openssl \
             openssl-dev \
             py3-pip \
             python3 \
             openjdk11 \
             aria2 \
             bzip2 \
             python3-dev && \
#
# Setup user
    addgroup -g 2000 cowrie && \
    adduser -S -s /bin/ash -u 2000 -D -g 2000 cowrie && \
#
# Install cowrie
    mkdir -p /home/cowrie && \
    cd /home/cowrie && \
    git clone --depth=1 https://github.com/micheloosterhof/cowrie -b v2.3.0 && \
    cd cowrie && \
#    git checkout 6b1e82915478292f1e77ed776866771772b48f2e && \
#    sed -i s/logfile.DailyLogFile/logfile.LogFile/g src/cowrie/python/logfile.py && \
    mkdir -p log && \
    sed -i '/packaging.*/d' requirements.txt && \
    pip3 install --upgrade pip && \
    pip3 install -r requirements.txt && \
#
# Setup configs
    export PYTHON_DIR=$(python3 --version | tr '[A-Z]' '[a-z]' | tr -d ' ' | cut -d '.' -f 1,2 ) && \
    setcap cap_net_bind_service=+ep /usr/bin/$PYTHON_DIR && \
    cp /root/dist/cowrie.cfg /home/cowrie/cowrie/cowrie.cfg && \
    chown cowrie:cowrie -R /home/cowrie/* /usr/lib/$PYTHON_DIR/site-packages/twisted/plugins && \
#
# Start Cowrie once to prevent dropin.cache errors upon container start caused by read-only filesystem
    su - cowrie -c "export PYTHONPATH=/home/cowrie/cowrie:/home/cowrie/cowrie/src && \
                    cd /home/cowrie/cowrie && \
                    /usr/bin/twistd --uid=2000 --gid=2000 -y cowrie.tac --pidfile cowrie.pid cowrie &" && \
    sleep 10 && \
#
# Clean up
    apk del --purge build-base \
                    git \
                    gmp-dev \
                    libcap \
                    libffi-dev \
                    mpc1-dev \
                    mpfr-dev \
                    openssl-dev \
                    python3-dev \
                    py3-mysqlclient && \
    rm -rf /root/* /tmp/* && \
    rm -rf /var/cache/apk/* && \
    rm -rf /home/cowrie/cowrie/cowrie.pid && \
    unset PYTHON_DIR

RUN mkdir -p /etc/listbot &&\
    cd /etc/listbot \
    aria2c -s16 -x 16 https://listbot.sicherheitstacho.eu/cve.yaml.bz2 &&\
    aria2c -s16 -x 16 https://listbot.sicherheitstacho.eu/iprep.yaml.bz2 &&\
    bunzip2 *.bz2

RUN set JAVA_OPTS="-Xms100m -Xmx100m" "-XX:PermSize=32m" "-XX:MaxPermSize=64m" "-XX:+HeapDumpOnOutOfMemoryError"
RUN mkdir -p /usr/share/logstash
RUN aria2c -s 16 -x 16 https://artifacts.elastic.co/downloads/logstash/logstash-oss-7.10.2-linux-x86_64.tar.gz
RUN tar xvfz logstash-oss-7.10.2-linux-x86_64.tar.gz --strip-components=1 -C /usr/share/logstash/
RUN rm -rf /usr/share/logstash/jdk
RUN /usr/share/logstash/bin/logstash-plugin install logstash-filter-translate
RUN /usr/share/logstash/bin/logstash-plugin install logstash-output-syslog
RUN mkdir -p /etc/logstash/conf.d/
ADD /dist/logstash.conf /etc/logstash/conf.d/logstash.conf
ADD /dist/tpot_es_template.json /etc/logstash/tpot_es_template.json
ADD /dist/update.sh /usr/bin/
RUN chmod 755 /usr/bin/update.sh

RUN mkdir -p /home/cowrie/cowrie/etc &&\
    mkdir /home/cowrie/cowrie/log &&\
    mkdir /home/cowrie/cowrie/log/tty
RUN chown -R cowrie:cowrie /home/cowrie
ADD /dist/services.sh /services.sh
RUN chown cowrie:cowrie /services.sh
RUN chmod +x /services.sh
RUN apk del --purge -y && \
    apk clean && \
    rm -rf /logstash-oss-7.10.2-linux-x86_64.tar.gz /var/lib/apt/lists/* /tmp/* /var/tmp/*
ENTRYPOINT ["./services.sh"]
