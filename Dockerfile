FROM rockylinux:8
MAINTAINER madebymode

ARG HOST_USER_UID=1000
ARG HOST_USER_GID=1000

# update dnf
RUN dnf -y update
RUN dnf -y install dnf-utils
RUN dnf clean all

# install epel-release
RUN dnf -y install epel-release


# install remi repo
RUN dnf -y install https://rpms.remirepo.net/enterprise/remi-release-8.rpm

# reset php
RUN  dnf module reset php -y    

# enable php8.0
RUN dnf module install php:remi-8.0 -y

# other binaries
RUN dnf -y install yum-utils mysql rsync wget git sudo which

# correct php install
RUN  dnf -y install php-{cli,fpm,mysqlnd,zip,devel,gd,mbstring,curl,xml,pear,bcmath,json,intl}

#fixes  ERROR: Unable to create the PID file (/run/php-fpm/php-fpm.pid).: No such file or directory (2)
RUN sed -e '/^pid/s//;pid/' -i /etc/php-fpm.conf
#fixes ERROR: failed to open error_log (/var/log/php-fpm/error.log): Permission denied (13), which running php-fpm as docker user
RUN sed -e '/^error_log\s\=\s\/var\/log\/php-fpm\/error.log/s//error_log = \/dev\/stderr/' -i /etc/php-fpm.conf

# Update and install latest packages and prerequisites
RUN dnf update -y \
    && dnf install -y --nogpgcheck --setopt=tsflags=nodocs \
        zip \
        unzip \
    && dnf clean all && dnf history new
    
#composer 1.10
RUN curl -sS https://getcomposer.org/installer | php -- --version=1.10.17 --install-dir=/usr/local/bin --filename=composer
#composer 2
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer2

RUN sed -e 's/\/run\/php\-fpm\/www.sock/9000/' \
        -e '/allowed_clients/d' \
        -e '/catch_workers_output/s/^;//' \
        -e '/error_log/d' \
        -i /etc/php-fpm.d/www.conf


RUN mkdir /run/php-fpm        

RUN echo 'Creating notroot docker user and group from host' && \
    groupadd -g $HOST_USER_GID docker && \
    useradd -lm -u $HOST_USER_UID -g $HOST_USER_GID docker

#  Add new user docker user to php-fpm (apache) group
RUN usermod -a -G apache docker
# give docker user sudo access
RUN usermod -aG wheel docker
# give docker user access to /dev/stdout and /dev/stderror
RUN usermod -aG tty docker

# Ensure sudo group users are not
# asked for a password when using
# sudo command by ammending sudoers file
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER docker



CMD ["php-fpm", "-F"]

EXPOSE 9000
