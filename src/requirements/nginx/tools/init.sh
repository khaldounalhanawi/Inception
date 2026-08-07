#!/bin/sh
DOMAIN_NAME=${DOMAIN_NAME}

sed -i "s/DOMAIN_NAME/$DOMAIN_NAME/g" /etc/nginx/nginx.conf

exec "$@"
