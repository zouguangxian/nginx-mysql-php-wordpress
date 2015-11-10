FROM ubuntu:14.04
MAINTAINER Zou Guangxian <zouguangxian@163.com>

# refer: https://github.com/docker-library/mysql/blob/master/5.7/Dockerfile

# the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit 
# way to disable the mysql_install_db codepath besides having a database already "configured"
# (ie, stuff in /var/lib/mysql/mysql) also, we set debconf keys to make APT a little quieter

RUN sed -i 's,http://archive\.ubuntu\.com/ubuntu/,http://mirrors\.163\.com/ubuntu/,g' /etc/apt/sources.list \
 && apt-get update \
 && { \
        echo mysql-community-server mysql-community-server/data-dir select ''; \
        echo mysql-community-server mysql-community-server/root-pass password ''; \
        echo mysql-community-server mysql-community-server/re-root-pass password ''; \
        echo mysql-community-server mysql-community-server/remove-test-db select false; \
    } | debconf-set-selections \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    supervisor \
    parallel \
    ssh \
    mysql-server \
    mysql-client \
    nginx \
    php5-fpm \
    php5-mysql \
    php-apc \
    pwgen \
    python-setuptools \
    curl \
    git \
    unzip \
    php5-curl \
    php5-gd \
    php5-intl \
    php-pear \
    php5-imagick \
    php5-imap \
    php5-mcrypt \
    php5-memcache \
    php5-ming \
    php5-ps \
    php5-pspell \
    php5-recode \
    php5-sqlite \
    php5-tidy \
    php5-xmlrpc \
    php5-xsl \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN \
 echo 'root:docker' | chpasswd \
 && sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
 && mkdir /var/run/sshd 

COPY ./services.conf /etc/supervisor/conf.d/
COPY ./nginx-default-site /etc/nginx/sites-available/default

COPY ./entry.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entry.sh

RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html

VOLUME /var/lib/mysql
EXPOSE 22 80

CMD ["/usr/local/bin/entry.sh"]
