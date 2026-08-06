FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y \
     php-fpm \
     php-mysql \
     php-redis \
     wget \
     curl && \
    apt-get clean

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf 
COPY tools/init.sh /usr/local/bin/init.sh 

RUN chmod +x /usr/local/bin/init.sh 

ENTRYPOINT ["/usr/local/bin/init.sh"]

CMD ["php-fpm8.2", "-F"]
