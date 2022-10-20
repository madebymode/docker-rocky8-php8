FROM rockylinux:8
MAINTAINER madebymode

ARG HOST_USER_UID=1000
ARG HOST_USER_GID=1000
ARG DUMB_INIT_RELEASE_ARCH=x86_64

# update dnf
RUN dnf -y update
RUN dnf -y install dnf-utils
RUN dnf clean all

# install epel-release
RUN dnf -y install epel-release

# reset php
RUN  dnf module reset php -y

# enable php8.0 - use official RHEL:8 module - cross platform & arch upstreams (remi only supplies x86)
RUN dnf module install php:8.0 -y

# other binaries
RUN dnf -y install yum-utils mysql rsync wget git expect sudo which

# correct php install
RUN  dnf -y install php-{cli,fpm,mysqlnd,zip,devel,gd,mbstring,curl,xml,pear,bcmath,json,intl}

RUN echo 'Creating notroot docker user and group from host' && \
    groupadd -f -g $HOST_USER_GID docker && \
    useradd -lm -u $HOST_USER_UID -g $HOST_USER_GID docker

#  Add new user docker user to php-fpm (apache) group
RUN usermod -a -G apache docker
# give docker user sudo access
RUN usermod -aG wheel docker
# give docker user access to /dev/stdout and /dev/stderror
RUN usermod -aG tty docker


# Update and install latest packages and prerequisites
RUN dnf update -y \
    && dnf install -y --nogpgcheck --setopt=tsflags=nodocs \
        zip \
        unzip \
    && dnf clean all && dnf history new

# DUMB INIT FOR entry-points
RUN wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_$DUMB_INIT_RELEASE_ARCH \
    && chmod +x /usr/local/bin/dumb-init

# init fake-entrypoint - we'll bind our custom script with volumes
RUN touch /entrypoint.sh \
    && echo '#!/bin/bash' >  /entrypoint.sh \
    && echo "" >>  /entrypoint.sh \
    && echo 'exec "$@"' >>  /entrypoint.sh \
    && chmod go+rwx /entrypoint.sh \
    && cat /entrypoint.sh

#composer 1.10
RUN curl -sS https://getcomposer.org/installer | php -- --version=1.10.17 --install-dir=/usr/local/bin --filename=composer
#composer 2
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer2

#wp-cli
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

RUN sed -e 's/\/run\/php\-fpm\/www.sock/9000/' \
        -e '/allowed_clients/d' \
        -e '/catch_workers_output/s/^;//' \
        -e '/error_log/d' \
        -i /etc/php-fpm.d/www.conf

RUN mkdir /run/php-fpm

#fixes  ERROR: Unable to create the PID file (/run/php-fpm/php-fpm.pid).: No such file or directory (2)
RUN chown docker:apache -R /run/php-fpm
# previous fix for above
#RUN sed -e '/^pid/s//;pid/' -i /etc/php-fpm.conf

#fixes ERROR: failed to open error_log (/var/log/php-fpm/error.log): Permission denied (13), which running php-fpm as docker user
RUN sed -e '/^error_log\s\=\s\/var\/log\/php-fpm\/error.log/s//error_log = \/dev\/stderr/' -i /etc/php-fpm.conf
#fixes ERROR: Unable to set php_value 'soap.wsdl_cache_dir' : Unable to set php_value 'soap.wsdl_cache_dir'"
RUN sed -e '/^php_value\[soap.wsdl_cache_dir\]/s//\;php_value\[soap.wsdl_cache_dir\]/' -i /etc/php-fpm.d/www.conf


# fix php perms
RUN chown apache:apache -R /var/lib/php/

# Ensure wheel group users are not
# asked for a password when using
# sudo command by ammending sudoers file
RUN echo '%wheel ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER docker

ENTRYPOINT ["/usr/local/bin/dumb-init", "/entrypoint.sh"]

CMD ["php-fpm", "-F"]

EXPOSE 9000
