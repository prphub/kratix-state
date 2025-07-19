FROM "alpine"

LABEL org.opencontainers.image.authors="kratix@syntasso.io"
LABEL org.opencontainers.image.source=https://github.com/prphub/kratix-state

RUN [ "mkdir", "/tmp/transfer" ]
RUN apk update && apk add --no-cache yq

ADD resources/ /tmp/transfer/
COPY execute-pipeline execute-pipeline
RUN chmod +x execute-pipeline

CMD [ "sh", "-c", "./execute-pipeline" ]
ENTRYPOINT []