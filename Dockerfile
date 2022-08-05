FROM nginx:1-alpine

RUN apk update && \
    apk upgrade && \
    apk --no-cache add aws-cli bash jq && \
    rm -rf /var/cache/apk/*

COPY ./custom-entrypoint.sh /docker-entrypoint.d/custom-entrypoint.sh

COPY ./html/ /var/www/html/

COPY ./websites/ /websites/

COPY ./conf /conf

RUN ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
