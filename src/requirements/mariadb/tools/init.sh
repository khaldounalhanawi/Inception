#!/bin/sh

set -e

MYSQL_PASSWORD=$(cat /run/secrets/db_password)

if [ ! -d "/var/lib/mysql/mysql" ]; then

    echo "Initializing database..."

    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql

    chown -R mysql:mysql /var/lib/mysql

fi

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

if [ ! -d "/var/lib/mysql/$MYSQL_DATABASE" ]; then

    echo "Creating $MYSQL_DATABASE database..."

    mysqld_safe --user=mysql --skip-networking &

    until mariadb -e "SELECT 1;" >/dev/null 2>&1
    do
        sleep 1
    done

    sed \
        -e "s/PASSWORD_PLACEHOLDER/$MYSQL_PASSWORD/g" \
        -e "s/\${MYSQL_DATABASE}/$MYSQL_DATABASE/g" \
        -e "s/\${MYSQL_USER}/$MYSQL_USER/g" \
        /usr/local/bin/init.sql \
        | mariadb

    mariadb-admin shutdown

fi

exec gosu mysql "$@"
