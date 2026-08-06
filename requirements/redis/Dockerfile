FROM debian:bookworm

RUN apt update && apt install -y redis-server

COPY conf/redis.conf /etc/redis/redis.conf
COPY tools/init.sh /init.sh

RUN chmod +x /init.sh

CMD ["/init.sh"]