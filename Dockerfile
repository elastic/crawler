FROM jruby:9.4.12.0-jdk21@sha256:5641622b488d298362b96fdaea0f328248ce55962e68e224118be11ddb48d16e
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libicu-dev netbase make

# used for skipping jenv/rbenv setup
ENV IS_DOCKER=1

COPY . /app
WORKDIR /app
RUN make clean install

# Clean up build dependencies
RUN rm -r /root/.m2

ENTRYPOINT [ "/bin/bash" ]
