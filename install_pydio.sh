apt-get update && apt-get upgrade -y
wget -O- http://nginx.org/keys/nginx_signing.key | apt-key add -
wget -O- https://www.dotdeb.org/dotdeb.gpg | apt-key add -
echo deb http://nginx.org/packages/debian/ jessie nginx > /etc/apt/sources.list.d/nginx.list
echo deb-src http://nginx.org/packages/debian/ jessie nginx >> /etc/apt/sources.list.d/nginx.list
echo "deb http://packages.dotdeb.org jessie all" > /etc/apt/sources.list.d/dotdeb.list

apt-get update
apt install -y nginx mysql-server php7.0 php7.0-fpm php7.0-mysql php7.0-curl php7.0-json php7.0-gd php7.0-intl php7.0-mbstring php7.0-xml php7.0-zip php7.0-exif php7.0-apcu

chown -R www-data:www-data /var/www

pydio_version="8.0.0"

cd /var/www
wget --no-check-certificate https://download.pydio.com/pub/core/archives/pydio-core-$pydio_version.tar.gz
tar -xzf pydio-core-$pydio_version.tar.gz
mv pydio-core-$pydio_version pydio
rm -R /var/www/pydio-core-$pydio_version.tar.gz
chown -R www-data:www-data /var/www/pydio

echo 'file_uploads = On
post_max_size = 20G
upload_max_filesize = 20G
max_file_uploads = 20000
output_buffering = Off' >> /etc/php/7/fpm/php.ini

/etc/init.d/php7.0-fpm restart

echo'server {
    listen 80;
    server_name pydio;
    rewrite ^ https://$server_name$request_uri? permanent;
}

server {
    listen 443 ssl;
    ### Change the following line to match your website name
    server_name YOUR_SERVER_NAME;
    root /var/www/pydio;
    index index.php;

    ### If you changed the maximum upload size in PHP.ini, also change it below
    client_max_body_size 20G;

    # Prevent Clickjacking
    add_header X-Frame-Options "SAMEORIGIN";

    # SSL Settings
    ### If you are using different names for your SSL certificate and key, change them below:
    ssl on;
    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;

    # This settings are destined to limit the supported crypto suites, this is optional and may restrict the availability of your website.
    #ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';
    #ssl_protocols TLSv1 TLSv1.1 TLSv1.2;

    add_header Strict-Transport-Security "max-age=16070400; includeSubdomains";

    keepalive_requests    10;
    keepalive_timeout     60 60;
    access_log /var/log/nginx/access_pydio7.log;
    error_log /var/log/nginx/error_pydio7.log;

    client_body_buffer_size 128k;
    # All non existing files are redirected to index.php
    if (!-e $request_filename){
        # For old links generated from Pydio 6
        rewrite ^/data/public/([a-zA-Z0-9_-]+)$ /public/$1?;
        rewrite ^(.*)$ /index.php last;
    }

    # Manually deny some paths to ensure Pydio security
    location ~* ^/(?:\.|conf|data/(?:files|personal|logs|plugins|tmp|cache)|plugins/editor.zoho/agent/files) {
            deny all;
    }

    # Forward PHP so that it can be executed
    location ~ \.php$ {

            fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
            fastcgi_param  SERVER_SOFTWARE    nginx;
            fastcgi_param  QUERY_STRING       $query_string;
            fastcgi_param  REQUEST_METHOD     $request_method;
            fastcgi_param  CONTENT_TYPE       $content_type;
            fastcgi_param  CONTENT_LENGTH     $content_length;
            fastcgi_param  SCRIPT_FILENAME    $document_root$fastcgi_script_name;
            fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;
            fastcgi_param  REQUEST_URI        $request_uri;
            fastcgi_param  DOCUMENT_URI       $document_uri;
            fastcgi_param  DOCUMENT_ROOT      $document_root;
            fastcgi_param  SERVER_PROTOCOL    $server_protocol;
            fastcgi_param  REMOTE_ADDR        $remote_addr;
            fastcgi_param  REMOTE_PORT        $remote_port;
            fastcgi_param  SERVER_ADDR        $server_addr;
            fastcgi_param  SERVER_PORT        $server_port;
            fastcgi_param  SERVER_NAME        $server_name;

            try_files $uri =404;
            fastcgi_pass unix:/run/php/php7.0-fpm.sock ;
    }

    # Enables Caching
    location ~* \.(ico|css|js)$ {
        expires 7d;
        add_header Pragma public;
        add_header Cache-Control "public, must-revalidate, proxy-revalidate";
    }
}' > /etc/nginx/sites-available/pydio.conf

rm /etc/nginx/sites-available/default

exit 0
