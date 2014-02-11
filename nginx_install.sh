#!/bin/bash
# Inspired by http://www.jeffmould.com/2013/11/26/install-nginx-source-ubuntu-12-04/
# Adapted for Ubuntu 14.04


# update system
apt-get update
apt-get -f upgrade 

#install requierements
apt-get install -f build-essential zlib1g-dev libpcre3 libpcre3-dev unzip make libssl-dev
apt-get install -f libc6 libexpat1  libgd2-xpm-dev libgeoip1 libgeoip-dev libpam0g libssl1.0.0 libxml2 libxslt1.1  zlib1g libperl5.18 perl  openssl  libgd2-xpm-dev libgeoip-dev  libxslt1-dev

#create user
adduser --system --no-create-home --disabled-login --disabled-password --group www-data

#get sources
mkdir /opt/nginx-src
cd /opt/nginx-src
wget http://nginx.org/download/nginx-1.5.10.tar.gz
tar -xvzf nginx-1.5.10.tar.gz

#configure make install
cd /opt/nginx-src/nginx-1.5.10
./configure --prefix=/usr/share/nginx --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --user=www-data --group=www-data --http-client-body-temp-path=/var/lib/nginx/body --http-fastcgi-temp-path=/var/lib/nginx/fastcgi --http-log-path=/var/log/nginx/access.log --http-proxy-temp-path=/var/lib/nginx/proxy --http-scgi-temp-path=/var/lib/nginx/scgi --http-uwsgi-temp-path=/var/lib/nginx/uwsgi --lock-path=/var/lock/nginx.lock --pid-path=/run/nginx.pid --with-pcre-jit --with-debug --with-http_addition_module --with-http_geoip_module --with-http_gzip_static_module --with-http_image_filter_module --with-http_realip_module --with-http_stub_status_module --with-http_ssl_module --with-http_sub_module --with-http_xslt_module --with-ipv6 --with-mail --with-mail_ssl_module --with-http_spdy_module

make
make install

#create structure
mkdir /var/cache/nginx
mkdir /var/ngx_pagespeed_cache
mkdir /var/log/nginx
mkdir /var/log/pagespeed
mkdir /etc/nginx/conf.d
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /var/lib/nginx/body
chown -R www-data:www-data /var/cache/nginx
chown -R www-data:www-data /var/ngx_pagespeed_cache
chown -R www-data:www-data /var/log/nginx
chown -R www-data:www-data /var/log/pagespeed
chown -R www-data:www-data /etc/nginx/sites-available
chown -R www-data:www-data /etc/nginx/sites-enabled 
chown -R www-data:www-data /var/lib/nginx/body

#create launcher
cat <<'EOF' > /etc/init.d/nginx
#!/bin/sh

### BEGIN INIT INFO
# Provides:          nginx
# Required-Start:    $local_fs $remote_fs $network $syslog
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts the nginx web server
# Description:       starts nginx using start-stop-daemon
### END INIT INFO

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
#DAEMON=/usr/sbin/nginx
DAEMON=/usr/share/nginx/sbin/nginx
NAME=nginx
DESC=nginx

# Include nginx defaults if available
if [ -f /etc/default/nginx ]; then
        . /etc/default/nginx
fi

test -x $DAEMON || exit 0

set -e
. /lib/lsb/init-functions

test_nginx_config() {
        if $DAEMON -t $DAEMON_OPTS >/dev/null 2>&1; then
                return 0
        else
                $DAEMON -t $DAEMON_OPTS
                return $?
        fi
}

case "$1" in
        start)
                echo -n "Starting $DESC: "
                test_nginx_config
                # Check if the ULIMIT is set in /etc/default/nginx
                if [ -n "$ULIMIT" ]; then
                        # Set the ulimits
                        ulimit $ULIMIT
                fi
                start-stop-daemon --start --quiet --pidfile /var/run/$NAME.pid \
                    --exec $DAEMON -- $DAEMON_OPTS || true
                echo "$NAME."
                ;;

        stop)
                echo -n "Stopping $DESC: "
                start-stop-daemon --stop --quiet --pidfile /var/run/$NAME.pid \
                    --exec $DAEMON || true
                echo "$NAME."
                ;;

        restart|force-reload)
                echo -n "Restarting $DESC: "
                start-stop-daemon --stop --quiet --pidfile \
                    /var/run/$NAME.pid --exec $DAEMON || true
                sleep 1
                test_nginx_config
                start-stop-daemon --start --quiet --pidfile \
                    /var/run/$NAME.pid --exec $DAEMON -- $DAEMON_OPTS || true
                echo "$NAME."
                ;;

        reload)
                echo -n "Reloading $DESC configuration: "
                test_nginx_config
                start-stop-daemon --stop --signal HUP --quiet --pidfile /var/run/$NAME.pid \
                    --exec $DAEMON || true
                echo "$NAME."
                ;;

        configtest|testconfig)
                echo -n "Testing $DESC configuration: "
                if test_nginx_config; then
                        echo "$NAME."
                else
                        exit $?
                fi
                ;;

        status)
                status_of_proc -p /var/run/$NAME.pid "$DAEMON" nginx && exit 0 || exit $?
                ;;
        *)
                echo "Usage: $NAME {start|stop|restart|reload|force-reload|status|configtest}" >&2
                exit 1
                ;;
esac

exit 0
EOF

chmod +x /etc/init.d/nginx

cat <<'EOF' > /etc/nginx/nginx.conf.ckd
worker_processes  1;
user www-data;
events {
    worker_connections  1024;
}
http {
    include       mime.types;
    default_type  application/octet-stream;
    
    fastcgi_cache_path /var/cache/nginx levels=1:2 keys_zone=microcache:10m max_size=1000m inactive=60m;
    
    sendfile        on;
    tcp_nopush on;
	tcp_nodelay on;
	client_body_timeout 10;
	send_timeout 10;
	server_tokens off;
    keepalive_timeout  65;
    
    include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;

    gzip on;
	gzip_http_version 1.1;
	gzip_comp_level 4;
	gzip_min_length 1024;
	gzip_proxied expired no-cache no-store private auth;
	gzip_types text/plain text/css application/x-javascript text/xml application/xml application/xml+rss text/javascript image/jpeg image/gif image/png;
	gzip_disable "MSIE [1-6]\.";

	open_file_cache max=2000 inactive=20s;
	open_file_cache_valid 30s;
	open_file_cache_min_uses 2;
	open_file_cache_errors on;


    server {
        listen       80;
        server_name  localhost;
        location / {
            root   html;
            index  index.html index.htm;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}
EOF

cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
cp /etc/nginx/nginx.conf.ckd /etc/nginx/nginx.conf

cat <<'EOF' > /etc/nginx/sites-available/default
server {
   listen 80;
   server_name mytest14;
   root /usr/share/nginx/html/;
   index info.php;

   location ~* /\.ht {
     deny all;
     access_log off;
     log_not_found off;
   }

   set $cache_uri $request_uri;
   if ($request_method = POST) {
      set $cache_uri 'null cache';
   }
   if ($query_string != "") {
      set $cache_uri 'null cache';
   }

   location = /favicon.ico { log_not_found off; access_log off; }
   location = /robots.txt { log_not_found off; access_log off; }

   location / {
      try_files $uri $uri/ /index.php?$query_string;
   }

   if (!-e $request_filename) {
      rewrite ^/(.+)/$ /index.php?/$1 last;
      break;
   }

   location ~* \.(?:ico|css|js|jpe?g|JPG|png|svg|woff)$ {
      expires 365d;
   }

   location ~ \.php(.*)$ {
      set $skip_cache 1;
      if ($cache_uri != "null cache") {
         add_header X-Cache_Debug "$cache_uri $cookie_nocache $arg_nocache$arg_comment $http_pragma $http_authorization";
         set $skip_cache 0;
      }

      fastcgi_cache_bypass $skip_cache;
      fastcgi_cache microcache;
      fastcgi_cache_key $scheme$host$request_uri$request_method;
      fastcgi_cache_valid any 8m;
      fastcgi_cache_use_stale updating;
      fastcgi_cache_bypass $http_pragma;
      fastcgi_cache_use_stale updating error timeout invalid_header http_500;

      fastcgi_pass unix:/var/run/php5-fpm.sock;
      try_files $uri = 404;
      fastcgi_split_path_info ^(.+\.php)(/.+)$;
      fastcgi_index index.php;
      fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
      include fastcgi_params;
    }
}
EOF

cat <<'EOF' > /usr/share/nginx/html/info.php
<?php phpinfo();?>
EOF

#install php5

apt-get install php5 php5-fpm php5-apcu php5-curl php5-mcrypt php5-gd php5-json php5-mysql

#End 
echo "Enable default vhost mytest14 with : ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/"
echo "Tweack your hosts file with mytest14 and according IP"
echo "You can now use /etc/init.d/nginx start"
echo "And test http://mytest14"
