FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y mariadb-server procps gosu && \
    apt-get clean

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
RUN chmod 644 /etc/mysql/mariadb.conf.d/50-server.cnf

COPY tools/init.sh /usr/local/bin/init.sh
COPY tools/init.sql /usr/local/bin/init.sql

RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT ["/usr/local/bin/init.sh"]

CMD ["mariadbd"]
