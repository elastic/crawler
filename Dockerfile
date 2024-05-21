FROM jruby:9.4.7.0-jdk21
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libicu-dev netbase make

# used for skipping jenv/rbenv setup
ENV IS_DOCKER=1

COPY . /app
WORKDIR /app
RUN make clean install

ENTRYPOINT [ "/bin/bash" ]
