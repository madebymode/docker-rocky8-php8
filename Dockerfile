FROM rockylinux:8
MAINTAINER madebymode

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
RUN dnf -y install yum-utils mysql rsync wget git 

# correct php install
RUN  dnf -y install php-{cli,fpm,mysqlnd,zip,devel,gd,mbstring,curl,xml,pear,bcmath,json,intl}

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

CMD ["php-fpm", "-F"]

EXPOSE 9000
