FROM ubuntu:22.04
#LABEL Author="Raja Subramanian" Description="A comprehensive docker image to run Apache-2.4 PHP-8.1 applications like Wordpress, Laravel, etc"

# Stop dpkg-reconfigure tzdata from prompting for input

#ENV DEBIAN_FRONTEND=noninteractive

ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC 
RUN apt-get update -y && apt-get -y install tzdata

# Install apache and php8.2
RUN apt -y update && apt -y upgrade

RUN apt install -y software-properties-common unzip

RUN apt-add-repository ppa:ondrej/php

RUN apt update -y

RUN apt -y install \
        apache2 \
        libapache2-mod-php \
        libapache2-mod-auth-openidc \
        php8.2-bcmath \
        php8.2-cli \
        php8.2-curl \
        php8.2-gd \
        php8.2-intl \
        php8.2-ldap \
	php8.2-pdo \
        php8.2-mbstring \
        php8.2-mysql \
        php8.2-pgsql \
        php8.2-soap \
        php8.2-tidy \
        php8.2-uploadprogress \
        php8.2-xmlrpc \
        php8.2-yaml \
        php8.2-zip \
# Ensure apache can bind to 80 as non-root
        libcap2-bin && \
    setcap 'cap_net_bind_service=+ep' /usr/sbin/apache2 && \
 
#    dpkg --purge libcap2-bin &&\
#    apt-get -y autoremove && \

# As apache is never run as root, change dir ownership
    a2disconf other-vhosts-access-log && \
    chown -Rh www-data. /var/run/apache2 && \

# Install ImageMagick CLI tools
    apt-get -y install --no-install-recommends imagemagick && \

# Clean up apt setup files
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \

# Setup apache
    a2enmod rewrite headers expires ext_filter

# Oracle instantclient

# copy oracle files
# ADD oracle/instantclient-basic-linux.x64-12.1.0.2.0.zip /tmp/
ADD https://download.oracle.com/otn_software/linux/instantclient/211000/instantclient-basic-linux.x64-21.1.0.0.0.zip /tmp/

# ADD oracle/instantclient-sdk-linux.x64-12.1.0.2.0.zip /tmp/
ADD https://download.oracle.com/otn_software/linux/instantclient/211000/instantclient-sdk-linux.x64-21.1.0.0.0.zip /tmp/

# ADD oracle/instantclient-sqlplus-linux.x64-12.1.0.2.0.zip /tmp/
ADD https://download.oracle.com/otn_software/linux/instantclient/211000/instantclient-sqlplus-linux.x64-21.1.0.0.0.zip /tmp/

# unzip them
RUN unzip /tmp/instantclient-basic-linux.x64-*.zip -d /usr/local/ \
    && unzip /tmp/instantclient-sdk-linux.x64-*.zip -d /usr/local/ \
    && unzip /tmp/instantclient-sqlplus-linux.x64-*.zip -d /usr/local/

# install oci8
RUN ln -s /usr/local/instantclient_*_1 /usr/local/instantclient \
    && ln -s /usr/local/instantclient/sqlplus /usr/bin/sqlplus 

RUN docker-php-ext-configure oci8 --with-oci8=instantclient,/usr/local/instantclient \
    && docker-php-ext-install oci8 \
    && echo /usr/local/instantclient/ > /etc/ld.so.conf.d/oracle-insantclient.conf \
    && ldconfig



# Override default apache and php config
COPY src/000-default.conf /etc/apache2/sites-available
COPY src/mpm_prefork.conf /etc/apache2/mods-available
COPY src/status.conf      /etc/apache2/mods-available
COPY src/99-local.ini     /etc/php/8.2/apache2/conf.d

# Expose details about this docker image
COPY src/index.php /var/www/html
RUN rm -f /var/www/html/index.html && \
    mkdir /var/www/html/.config && \
    tar cf /var/www/html/.config/etc-apache2.tar etc/apache2 && \
    tar cf /var/www/html/.config/etc-php.tar     etc/php && \
    dpkg -l > /var/www/html/.config/dpkg-l.txt


EXPOSE 80
USER www-data

ENTRYPOINT ["apache2ctl", "-D", "FOREGROUND"]
