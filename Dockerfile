# A dockerfile for setting up Zulip!
FROM ubuntu:trusty

MAINTAINER Shantanu Choudhary <shantanu.choudhary@spanacross.com>

ADD zulip_docker.sh /usr/local/bin/

# System update
RUN apt-get update

# Install packages from apt
ENV APT_DEPENDENCIES="libffi-dev \
    python-virtualenv \
    git \
    npm \
    yui-compressor \
    puppet \
    sudo \
    bc \
    supervisor \
    wget \
    libjpeg62 \
    libfreetype6 \
    libtiff5 \
    libwebp5 \    
    memcached \
    rabbitmq-server \
    libmemcached-dev \
    python-dev \
    libpq-dev \
    libldap2-dev \
    nodejs \
    libfreetype6-dev \
    postgresql-client \
    postgresql \ 
    postgresql-contrib \
    hunspell-en-us \
    closure-compiler \
    redis-server \
    node-jquery"

RUN DEBIAN_FRONTEND=noninteractive apt-get -y --fix-missing install $APT_DEPENDENCIES

# Install tsearch for postgresql
ENV TSEARCH_URL_BASE="https://dl.dropboxusercontent.com/u/283158365/zuliposs"
ENV TSEARCH_PACKAGE_NAME="postgresql-9.4-tsearch-extras"
ENV TSEARCH_VERSION="0.1"
ENV ARCH="amd64"
ENV TSEARCH_URL="$TSEARCH_URL_BASE"/"$TSEARCH_PACKAGE_NAME"_"$TSEARCH_VERSION"_"$ARCH".deb
ENV TMP_PACKAGE="/tmp/package_XXXXXX.deb"

RUN wget -c $TSEARCH_URL -O $TMP_PACKAGE
RUN dpkg -i $TMP_PACKAGE

ENV RABBITMQ_LOG_BASE /home/baali/rabbitmq-docker/data/log
ENV RABBITMQ_MNESIA_BASE /home/baali/rabbitmq-docker/data/mnesia

# Define mount points.
VOLUME ["/home/baali/rabbitmq-docker/data/log", "/home/baali/rabbitmq-docker/data/mnesia"]

# Install Phantomjs
ENV PHANTOMJS_PATH="/srv/phantomjs"
ENV PHANTOMJS_TARBALL="$PHANTOMJS_PATH"/"phantomjs-1.9.8-linux-x86_64.tar.bz2"
RUN mkdir -p $PHANTOMJS_PATH
RUN wget -c https://github.com/ariya/phantomjs/archive/1.9.8.tar.gz -O $PHANTOMJS_TARBALL
RUN cd $PHANTOMJS_PATH && tar -xzf $PHANTOMJS_TARBALL
RUN ln -sf "$PHANTOMJS_PATH"/phantomjs-1.9.8-linux-x86_64/bin/phantomjs \
    /usr/local/bin/phantomjs

# Create zulip user and group!
ENV ZULIP_USER=zulip
ENV ZULIP_HOME=/srv
ENV ZULIP_PATH="/srv/zulip"
RUN groupadd -r $ZULIP_USER \
    && useradd -r -g $ZULIP_USER -d $ZULIP_HOME -s /usr/sbin/nologin $ZULIP_USER
# RUN adduser $ZULIP_USER sudo
RUN rm -rf $ZULIP_PATH

# Get zulip source
WORKDIR $ZULIP_HOME
RUN git clone https://github.com/zulip/zulip.git
ADD dev-secrets.conf $ZULIP_PATH/zproject/
ADD forms.py $ZULIP_PATH/zerver/
ADD initialize_bots.py $ZULIP_PATH/zerver/management/commands/
ADD settings.py $ZULIP_PATH/zproject/
ADD process_fts_updates $ZULIP_PATH/puppet/zulip/files/postgresql/
RUN chown -R $ZULIP_USER:$ZULIP_USER $ZULIP_HOME
# RUN chmod g+r $ZULIP_PATH/zproject/dev-secrets.conf

RUN chmod +x /usr/local/bin/zulip_docker.sh

# Setup virtualenv
ENV VENV_PATH="/srv/zulip-venv"
RUN rm -rf $VENV_PATH
RUN mkdir -p $VENV_PATH
RUN chown -R $ZULIP_USER:$ZULIP_USER $VENV_PATH
USER $ZULIP_USER
RUN virtualenv $VENV_PATH

# Install requirements
RUN . $VENV_PATH/bin/activate && pip install -r $ZULIP_PATH/requirements.txt
RUN cat $ZULIP_PATH/requirements.txt

# Setting DB here as root user
USER root

# FIXME: Install node-jquery and additional deps.
# Add additional node packages for test-js-with-node.
# ENV NPM_DEPENDENCIES="cssstyle \
#     htmlparser2 \
#     nwmatcher"

# Management commands expect to be run from the root of the project.
WORKDIR $ZULIP_PATH

CMD ["/usr/local/bin/zulip_docker.sh"]

EXPOSE 9991

# Start required services
# CMD service rabbitmq-server start && service memcached start && service postgresql start && service redis-server start && $ZULIP_PATH/zulip_docker.sh
# CMD ["service", "rabbitmq-server", "start"]
