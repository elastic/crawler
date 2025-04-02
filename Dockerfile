FROM jruby:9.4.12.0-jdk21@sha256:5641622b488d298362b96fdaea0f328248ce55962e68e224118be11ddb48d16e
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libicu-dev netbase make

# used for skipping jenv/rbenv setup
ENV IS_DOCKER=1

COPY . /home/app
WORKDIR /home/app
RUN make clean install

# Clean up build dependencies
RUN rm -r /root/.m2

# Set up crawlergroup and crawleruser
RUN groupadd -g 451 crawlergroup && \
    useradd -m -u 451 -g crawlergroup crawleruser

# change ownership and permissions of /home/app
WORKDIR /home
RUN chown -R crawleruser:crawlergroup app
RUN chmod -R 775 app

# reset workdir and crawleruser as user
WORKDIR /home/app
USER crawleruser

ENTRYPOINT [ "/bin/bash" ]
