#######################
# Get composer packages
FROM composer as phpDependencies
WORKDIR /application

COPY composer.json composer.lock ./

RUN composer install --no-autoloader

COPY . .

RUN composer dump-autoload --quiet


######################
# Build browser assets
FROM node:8 as nodeDependencies
WORKDIR /application

COPY package.json yarn.lock ./

RUN yarn install

COPY . .

RUN yarn production


FROM nginx:1.13.12 as server

WORKDIR /etc/nginx/conf.d/
COPY default.conf .

COPY --from=nodeDependencies /application/public/ /application/public/

############################
# Setup Laravel requirements
FROM php:7.2.5-fpm as common
WORKDIR /application

# MySQL database driver
RUN docker-php-ext-install pdo_mysql


########################################
# Run the application (development mode)
FROM common as development

# Install NodeJs to compile assets
RUN apt-get update \
 && apt-get install --assume-yes wget gnupg gcc g++ make apt-transport-https libpng-dev \
 && curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
 && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
 && curl -sL https://deb.nodesource.com/setup_8.x | bash - \
 && apt-get install --assume-yes nodejs supervisor yarn \
 && rm -rf /var/lib/apt/lists/*

COPY supervisor.conf /etc/supervisor/conf.d/

COPY . .
RUN chown -R www-data:www-data .

# Get application source code
COPY --from=phpDependencies /application/vendor/ ./vendor/
COPY --from=nodeDependencies /application/node_modules/ ./node_modules/

CMD [ "/usr/bin/supervisord" ]


###############################
# Run the application (release)
FROM common as release

# Set Default environments
ARG RELEASE
ENV RELEASE_VERSION $RELEASE

COPY . .
RUN chown -R www-data:www-data .

# Get application source code
COPY --from=phpDependencies /application/vendor/  ./vendor/
COPY --from=nodeDependencies /application/public/ ./public/

CMD ["php-fpm"]
ENTRYPOINT ["./entrypoint.sh"]
