# vim:set ft=dockerfile:

# Setup A Template Image
FROM centos:8

# Define ENV Variables
ARG TOKEN=${TOKEN}
ENV TINI_VERSION=v0.18.0
ENV MARIADB_VERSION=10.5

# Add MariaDB Enterprise Repo
ADD https://dlm.mariadb.com/enterprise-release-helpers/mariadb_es_repo_setup /tmp

RUN chmod +x /tmp/mariadb_es_repo_setup && \
    /tmp/mariadb_es_repo_setup --mariadb-server-version=${MARIADB_VERSION} --token=${TOKEN} --apply

# Update System
RUN dnf -y install epel-release && \
    dnf -y upgrade

# Install Various Packages/Tools
RUN dnf -y install bind-utils \
    bc \
    boost \
    expect \
    git \
    glibc-langpack-en \
    jemalloc \
    jq \
    less \
    libaio \
    monit \
    nano \
    net-tools \
    openssl \
    rsyslog \
    snappy \
    sudo \
    tcl \
    vim \
    wget

# Default Locale Variables
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# Install MariaDB Packages
RUN dnf -y install \
     MariaDB-shared \
     MariaDB-client \
     MariaDB-server \
     MariaDB-columnstore-engine \
     mariadb-columnstore-cmapi

# Copy Config Files & Scripts To Image
COPY config/etc/ /etc/
COPY scripts/provision \
     scripts/columnstore-init \
     scripts/cmapi-start \
     scripts/cmapi-stop \
     scripts/cmapi-restart \
     scripts/mcs-process /usr/bin/

# Add Tini Init Process
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini

# Make Scripts Executable
RUN chmod +x /usr/bin/tini \
    /usr/bin/provision \
    /usr/bin/columnstore-init \
    /usr/bin/cmapi-start \
    /usr/bin/cmapi-stop \
    /usr/bin/cmapi-restart \
    /usr/bin/mcs-process && \
    sed -i '126s/smcat/SMCAT/g' /usr/bin/mcs-loadbrm.py

# Stream Edit Monit Config
RUN sed -i 's|set daemon\s.30|set daemon 5|g' /etc/monitrc && \
    sed -i 's|#.*with start delay\s.*240|  with start delay 60|' /etc/monitrc

# Create Persistent Volumes
VOLUME ["/etc/columnstore", "/etc/my.cnf.d","/var/lib/mysql","/var/lib/columnstore"]

# Copy Entrypoint To Image
COPY scripts/docker-entrypoint.sh /usr/bin/

# Do Some Housekeeping
RUN chmod +x /usr/bin/docker-entrypoint.sh && \
    ln -s /usr/bin/docker-entrypoint.sh /docker-entrypoint.sh && \
    sed -i 's|SysSock.Use="off"|SysSock.Use="on"|' /etc/rsyslog.conf && \
    sed -i 's|^.*module(load="imjournal"|#module(load="imjournal"|g' /etc/rsyslog.conf && \
    sed -i 's|^.*StateFile="imjournal.state")|#  StateFile="imjournal.state")|g' /etc/rsyslog.conf && \
    dnf clean all && \
    rm -rf /var/cache/dnf && \
    find /var/log -type f -exec cp /dev/null {} \; && \
    cat /dev/null > ~/.bash_history && \
    history -c

# Bootstrap
ENTRYPOINT ["/usr/bin/tini","--","docker-entrypoint.sh"]
CMD cmapi-start && monit -I
