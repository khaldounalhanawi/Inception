FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y nginx openssl && \
    apt-get clean

RUN mkdir -p /etc/nginx/ssl

RUN openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/server.key \
    -out /etc/nginx/ssl/server.crt \
    -subj "/C=DE/ST=Berlin/L=Berlin/O=42/OU=Inception/CN=kalhanaw.42.f4"


COPY conf/nginx.conf etc/nginx/nginx.conf
COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT ["/usr/local/bin/init.sh"]

CMD ["nginx", "-g", "daemon off;"]
