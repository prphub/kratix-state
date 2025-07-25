FROM alpine:3.18

LABEL org.opencontainers.image.authors="kratix@syntasso.io"
LABEL org.opencontainers.image.source=https://github.com/prphub/kratix-state

# # Install required packages (using --no-cache like PostgreSQL pattern)
# RUN apk update && apk add --no-cache curl jq yq kubectl bash coreutils

# Install required packages (without kubectl)
RUN apk update && apk add --no-cache curl jq yq bash coreutils

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Copy scripts (following PostgreSQL pattern)
ADD execute-pipeline execute-pipeline
ADD scripts/* ./scripts/

# Make scripts executable
RUN chmod +x execute-pipeline scripts/*

# Set the default command (following PostgreSQL pattern)
CMD [ "sh", "-c", "./execute-pipeline" ]
ENTRYPOINT []
