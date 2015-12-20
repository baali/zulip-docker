#!/bin/bash

ulimit -n 1024
mkdir -p ~/rabbitmq-docker/data
chown -R rabbitmq:rabbitmq ~/rabbitmq-docker/data
rabbitmq-server -detached

service memcached start

redis-server /etc/redis/redis.conf
service postgresql start

sleep 5s
ZULIP_USER="zulip"
ZULIP_HOME="/srv"
ZULIP_PATH="/srv/zulip"

# Copy stopwords file for tsearch
wget https://raw.githubusercontent.com/zulip/zulip/master/puppet/zulip/files/postgresql/zulip_english.stop
TSEARCH_STOPWORDS_PATH="/usr/share/postgresql/9.3/tsearch_data/"
cp zulip_english.stop $TSEARCH_STOPWORDS_PATH

# Get virtualenv ready and do initial setup of DB and other things
VENV_PATH="/srv/zulip-venv"
. $VENV_PATH/bin/activate
# Had to checkout previous version as webpack-dev was not playing
# nicely along with everything else
git config --global user.name "UserName"
git config --global user.email "user@example.com"
git stash
git checkout ae04744
git stash pop
cd $ZULIP_PATH
tools/download-zxcvbn
tools/emoji_dump/build_emoji

scripts/setup/configure-rabbitmq
tools/postgres-init-dev-db
tools/do-destroy-rebuild-database
tools/postgres-init-test-db
# tools/do-destroy-rebuild-test-database

su -s /bin/bash -c ". $VENV_PATH/bin/activate && ./manage.py migrate" -m "$ZULIP_USER"
# su -s /bin/bash -c ". $VENV_PATH/bin/activate && ./manage.py initialize_bots --name='domain.com'" -m "$ZULIP_USER"
su -s /bin/bash -c ". $VENV_PATH/bin/activate && tools/run-dev.py --interface=''" -m "$ZULIP_USER"
