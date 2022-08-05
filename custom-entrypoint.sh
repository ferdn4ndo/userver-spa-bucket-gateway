#!/bin/sh

set -e

conf_file_content=$(cat /conf/headers.conf)

DEBUG_CONF=""
if [ "$DEBUG" == "1" ]; then
    echo "Running in DEBUG mode!"
    DEBUG_CONF='
        add_header X-Debug-Proxy-Url "http://$bucket${uri}" always;
        add_header X-Debug-Bucket "$bucket" always;
        add_header X-Debug-Uri "${uri}" always;
'
else
    echo "Debugging is disabled!"
fi

if [ "$TRAILING_SLASH" == "1" ]; then
    echo "Adding rule to enforce trailing slashes"
    TRAILING_SLASH_CONF='
        # Appends a trailing slash
        rewrite ^([^.]*[^/])$ $1/ permanent;
'
else
    echo "Adding rule to remove trailing slashes"
    TRAILING_SLASH_CONF='
        # Removes the trailing slash
        rewrite ^/(.*)/$ /$1 permanent;
'
fi

for file in /websites/*.json; do
    [ -f "$file" ] || break
    echo "Reading website from file '$file'..."

    BUCKET_URL=$(cat $file | jq -r '.BUCKET_URL')
    DOMAIN=$(cat $file | jq -r '.DOMAIN')

    template="
# Template parsed from file '$file'
$(cat /conf/base-website.conf)
"

    template="${template//%%BUCKET_URL%%/$BUCKET_URL}"
    template="${template//%%DEBUG_CONF%%/$DEBUG_CONF}"
    template="${template//%%TRAILING_SLASH_CONF%%/$TRAILING_SLASH_CONF}"
    template="${template//%%DOMAIN%%/$DOMAIN}"

    conf_file_content="$conf_file_content$template"
done

conf_file_content="$conf_file_content
$(cat /conf/default-server.conf)"

echo "$conf_file_content" > /etc/nginx/conf.d/default.conf

echo "DEFAULT CONF CREATED!"

if [ "$DEBUG" == "1" ]; then
    echo "Conf file (/etc/nginx/conf.d/default.conf) content:"
    cat /etc/nginx/conf.d/default.conf
else
    echo "To check the final conf file, run:"
    echo "  docker exec -it userver-serverless-gateway sh -c \"cat /etc/nginx/conf.d/default.conf\""
fi

echo "Custom config generation finished! Resuming the nginx loading..."
