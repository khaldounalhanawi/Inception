#!/bin/sh

MYSQL_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_GUEST_PASSWORD=$(cat /run/secrets/wp_guest_password)

if [ ! -f "/var/www/html/wp-config.php" ]; then
 wget https://wordpress.org/latest.tar.gz
 tar -xzf latest.tar.gz
 cp -r wordpress/* /var/www/html
 rm -rf wordpress latest.tar.gz

cd /var/www/html

wp config create \
    --dbname="$MYSQL_DATABASE" \
    --dbuser="$MYSQL_USER" \
    --dbpass="$MYSQL_PASSWORD" \
    --dbhost=mariadb \
    --allow-root

wp config set WP_REDIS_HOST redis --allow-root
wp config set WP_REDIS_PORT 6379 --allow-root

fi

cd /var/www/html

if ! wp core is-installed --allow-root; then

    wp core install \
        --url="$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --allow-root

    wp user create \
        "$WP_GUEST_USER" \
        "$WP_GUEST_EMAIL" \
        --role=subscriber \
        --user_pass="$WP_GUEST_PASSWORD" \
        --allow-root
fi

if ! wp plugin is-active redis-cache --allow-root; then
    wp plugin install redis-cache --activate --allow-root
fi

if [ ! -f "wp-content/object-cache.php" ]; then
    wp redis enable --allow-root
fi

chown -R www-data:www-data /var/www/html

exec "$@"