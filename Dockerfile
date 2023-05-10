ARG PHP_VERSION="8.1.17"
ARG DEBIAN_VERSION="bullseye"

FROM php:${PHP_VERSION}-fpm-${DEBIAN_VERSION} as pimcore_php_fpm

RUN set -eux; \
  DPKG_ARCH="$(dpkg --print-architecture)"; \
  apt-get update; \
  apt-get install -y lsb-release; \
  echo "deb http://deb.debian.org/debian $(lsb_release -sc)-backports main" > /etc/apt/sources.list.d/backports.list; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    autoconf automake libtool nasm make pkg-config libz-dev build-essential openssl g++ \
    zlib1g-dev libicu-dev libbz2-dev zopfli libc-client-dev default-jre \
    libkrb5-dev libxml2-dev libxslt1.1 libxslt1-dev locales locales-all \
    ffmpeg html2text ghostscript libreoffice pngcrush jpegoptim exiftool poppler-utils git wget \
    libx11-dev python3-pip opencv-data facedetect webp graphviz cmake ninja-build unzip cron \
    liblcms2-dev liblqr-1-0-dev libjpeg-turbo-progs libopenjp2-7-dev libtiff-dev \
    libfontconfig1-dev libfftw3-dev libltdl-dev liblzma-dev libopenexr-dev \
    libwmf-dev libdjvulibre-dev libpango1.0-dev libxext-dev libxt-dev librsvg2-dev libzip-dev \
    libpng-dev libfreetype6-dev libjpeg-dev libxpm-dev libwebp-dev libjpeg62-turbo-dev \
    xfonts-75dpi xfonts-base libjpeg62-turbo \
    libonig-dev optipng pngquant inkscape; \
  \
  openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096; \
  apt-get install -y libavif-dev libheif-dev optipng pngquant chromium chromium-sandbox; \
  docker-php-ext-configure pcntl --enable-pcntl; \
  docker-php-ext-install pcntl intl mbstring mysqli bcmath bz2 soap xsl pdo pdo_mysql fileinfo exif zip opcache sockets; \
  \
  wget https://imagemagick.org/archive/ImageMagick.tar.gz; \
    tar -xvf ImageMagick.tar.gz; \
    cd ImageMagick-7.*; \
    ./configure; \
    make --jobs=$(nproc); \
    make V=0; \
    make install; \
    cd ..; \
    rm -rf ImageMagick*; \
  \
  docker-php-ext-configure gd -enable-gd --with-freetype --with-jpeg --with-webp; \
  docker-php-ext-install gd; \
  pecl install -f xmlrpc imagick apcu redis; \
  docker-php-ext-enable redis imagick apcu; \
  docker-php-ext-configure imap --with-kerberos --with-imap-ssl; \
  docker-php-ext-install imap; \
  docker-php-ext-enable imap; \
  ldconfig /usr/local/lib; \
  \
  cd /tmp; \
  \
  wget -O wkhtmltox.deb https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.buster_${DPKG_ARCH}.deb; \
    dpkg -i wkhtmltox.deb; \
    rm wkhtmltox.deb; \
  \
  apt-get autoremove -y; \
    apt-get remove -y autoconf automake libtool nasm make cmake ninja-build pkg-config libz-dev build-essential g++; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* ~/.composer || true; \
  sync;

# php log files
RUN mkdir /var/log/php; \
  touch /var/log/php/errors.log && chmod 664 /var/log/php/errors.log

ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_MEMORY_LIMIT -1
COPY --from=composer/composer:2-bin /composer /usr/bin/composer

FROM pimcore_php_fpm as pimcore_php_supervisord

# install nginx, supervisor, cron
RUN apt-get update && apt-get install -y nginx supervisor redis-server cron

# copy config/scripts
COPY ./ops/docker/run.sh /var/docker/run.sh
COPY ./ops/docker/php/php-prod.ini /usr/local/etc/php/conf.d/20-pimcore.ini
COPY ./ops/docker/php/fpm.conf /usr/local/etc/php-fpm.d/www.conf
COPY ./ops/docker/supervisord.conf /etc/supervisord.conf
COPY ./ops/docker/ngx/nginx.conf /etc/nginx/nginx.conf
COPY ./ops/docker/ngx/dam.conf /etc/nginx/sites-enabled/default
COPY ./ops/docker/ngx/ssl.conf /etc/nginx/ssl.conf
COPY ./ops/docker/ngx/exploit.conf /etc/nginx/snippets/exploit_protection.conf
COPY ./ops/docker/ngx/optimize.conf /etc/nginx/snippets/site_optimization.conf
COPY ./ops/docker/ngx/log.conf /etc/nginx/snippets/logging.conf

WORKDIR /var/www/html

# copy code
COPY --chown=www-data:www-data ./src /var/www/html

RUN usermod -a -G www-data root; \
  chown -R www-data:www-data .; \ 
  find . -type d -exec chmod 2775 {} \;; \
  find . -type f -exec chmod 0664 {} \;; \
  chmod +x bin/console; \
  chmod gu+rw /var/run; \
  chmod gu+s /usr/sbin/cron; \
  chmod +x /var/docker/run.sh

ENTRYPOINT ["/var/docker/run.sh"]