FROM debian AS builder

ARG PERCONA_VERSION="5.6.51-91.0"

RUN apt-get update && apt-get -y install \
	git \
	cmake \
	make \
	gcc \
	g++ \
	libaio-dev \
	libncurses5-dev \
	libreadline-dev \
	bison \
	libssl-dev \
	zlib1g-dev

RUN git clone --depth 1 -b release-$PERCONA_VERSION https://github.com/percona/percona-server.git \
	&& cd percona-server/ \
	&& git submodule init \
	&& git submodule update \
	&& cmake . \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo \
		-DBUILD_CONFIG=mysql_release \
		-DFEATURE_SET=community \
		-DWITH_EMBEDDED_SERVER=OFF \
		-DIGNORE_AIO_CHECK=ON \
		-DMYSQL_DATADIR=/var/lib/mysql \
		-DFORCE_INSOURCE_BUILD=1 \
		-DDOWNLOAD_BOOST=1 \
		-DWITH_BOOST=/tmp/boost \
	&& make \
	&& make install

FROM debian

RUN apt-get update && apt-get install -y libaio-dev libssl-dev libncurses5-dev libreadline-dev autoconf curl \
	&& apt-get clean autoclean \
	&& apt-get autoremove --yes \
	&& rm -rf /var/lib/{apt,dpkg,cache,log}/

COPY --from=builder /usr/local/mysql /usr/local/mysql

RUN groupadd -g 1001 mysql \
	&& useradd -u 1001 -r -g 1001 -s /sbin/nologin mysql

RUN install -m 0775 -o mysql -g root -d /etc/mysql/conf.d /var/lib/mysql /var/run/mysqld /docker-entrypoint-initdb.d

RUN echo '!includedir /etc/mysql/conf.d' >> /etc/my.cnf \
	&& chown -R mysql /var/lib/mysql /etc/mysql /etc/my.cnf

RUN curl -fsL -o /docker-entrypoint.sh https://raw.githubusercontent.com/docker-library/mysql/master/8.0/docker-entrypoint.sh \
	&& chmod +x /docker-entrypoint.sh

USER mysql

EXPOSE 3306

ENV PATH=$PATH:/usr/local/mysql/bin:/usr/local/mysql/scripts

VOLUME ["/var/lib/mysql", "/var/log/mysql"]

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["mysqld"]