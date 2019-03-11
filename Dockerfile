FROM php:7.2-fpm-alpine

# Calculate download URL
ENV VERSION 4.8.5
ENV URL https://files.phpmyadmin.net/phpMyAdmin/${VERSION}/phpMyAdmin-${VERSION}-all-languages.tar.xz
ENV THEME_URL https://files.phpmyadmin.net/themes/fallen/0.7/fallen-0.7.zip
LABEL version=$VERSION

# Install dependencies
RUN set -x \
    && apk add --no-cache --virtual .build-deps \
        bzip2-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libxpm-dev \
    && docker-php-ext-configure gd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-webp-dir=/usr --with-png-dir=/usr --with-xpm-dir=/usr \
    && docker-php-ext-install bz2 gd mysqli opcache zip \
    && runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )" \
    && apk add --no-cache --virtual .phpmyadmin-phpexts-rundeps $runDeps \
    && apk del .build-deps \
    && apk add --no-cache --virtual .fetch-deps \
        gnupg \
    && export GNUPGHOME="$(mktemp -d)" \
    && export GPGKEY="3D06A59ECE730EB71B511C17CE752F178259BD92" \
    && curl --silent --output phpMyAdmin.tar.xz --location "$URL" \
    && curl --silent --output phpMyAdmin.tar.xz.asc --location "$URL.asc" \
    && curl --silent --output theme.zip --location "$THEME_URL" \
    && curl --silent --output theme.zip.asc --location "$THEME_URL.asc" \
    && { \
        gpg -q --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPGKEY" \
            || gpg -q --keyserver ipv4.pool.sks-keyservers.net --recv-keys "$GPGKEY" \
            || gpg -q --keyserver keys.gnupg.net --recv-keys "$GPGKEY" \
            || gpg -q --keyserver pgp.mit.edu --recv-keys "$GPGKEY" \
            || gpg -q --keyserver keyserver.pgp.com --recv-keys "$GPGKEY"; \
    } \
    && gpg --batch --verify phpMyAdmin.tar.xz.asc phpMyAdmin.tar.xz \
    && gpg --batch --verify theme.zip.asc theme.zip \
    && tar -xf phpMyAdmin.tar.xz \
    && mv phpMyAdmin-$VERSION-all-languages phpMyAdmin \
    && unzip -q theme.zip -d phpMyAdmin/themes \
    && gpgconf --kill all \
    && rm -r \
        "$GNUPGHOME" \
        phpMyAdmin.tar.xz \
        phpMyAdmin.tar.xz.asc \
        theme.zip \
        theme.zip.asc \
    && rm -rf \
        phpMyAdmin/RELEASE-DATE-$VERSION \
        phpMyAdmin/composer.json \
        phpMyAdmin/examples/ \
        phpMyAdmin/po/ \
        phpMyAdmin/setup/ \
        phpMyAdmin/test/ \
    && sed -i "s@define('CONFIG_DIR'.*@define('CONFIG_DIR', '/etc/phpmyadmin/');@" phpMyAdmin/libraries/vendor_config.php \
    && chown -R www-data:www-data phpMyAdmin \
    && find phpMyAdmin -type d -exec chmod 755 {} \+ \
    && find phpMyAdmin -type f -exec chmod 644 {} \+ \
    # Add directory for sessions to allow session persistence
    && mkdir /sessions \
    && chown www-data:www-data /sessions \
    && mkdir -p phpMyAdmin/tmp \
    && chmod -R 777 phpMyAdmin/tmp \
    && XZ_OPT=-9e tar -Jcf /usr/src/phpMyAdmin.tar.xz -C phpMyAdmin . \
    && rm -rf phpMyAdmin \
    && apk del .fetch-deps \
    && rm -rf /var/cache/apk/*

VOLUME /var/www/html

# Copy configuration
COPY etc /etc/
COPY php.ini /usr/local/etc/php/conf.d/php-phpmyadmin.ini

# Copy main script
COPY run.sh /run.sh

# We expose phpMyAdmin on port 9000
EXPOSE 9000

CMD [ "/run.sh" ]
