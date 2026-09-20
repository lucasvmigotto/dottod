FROM dhi.io/debian-base:trixie-debian13-dev

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update && apt-get install -y sudo \
    && useradd -m -s /bin/bash testuser && \
        echo "testuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/testuser

USER testuser

COPY --chown=testuser:testuser \
    . /home/testuser/dottod


WORKDIR /home/testuser/dottod

RUN cat <<EOF > /home/testuser/test-bootstrap.sh
#!/bin/bash

set -e

bash ./bin/bootstrap.sh --no-ui-support

EOF
