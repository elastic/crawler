FROM jruby:9.3.14.0-jdk11
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libicu-dev netbase make

# used for skipping jenv/rbenv setup
ARG IS_DOCKER=1

ENTRYPOINT [ "/bin/bash" ]
