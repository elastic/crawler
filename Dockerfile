FROM jruby:9.4.7.0-jdk21@sha256:56592df1d1a9270f3871fce44ce3cb60f4f5c67bec6626397607ab8884dff419
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libicu-dev netbase make

# used for skipping jenv/rbenv setup
ENV IS_DOCKER=1

COPY . /app
WORKDIR /app
RUN make clean install

ENTRYPOINT [ "/bin/bash" ]
