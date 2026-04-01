FROM jruby:9.4.12.0-jdk21@sha256:5641622b488d298362b96fdaea0f328248ce55962e68e224118be11ddb48d16e
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libicu-dev netbase make

# used for skipping jenv/rbenv setup
ENV IS_DOCKER=1

# Set up crawlergroup and crawleruser
RUN groupadd -g 451 crawlergroup && \
    useradd -m -u 451 -g crawlergroup crawleruser

# Copy and set up Crawler as crawleruser
USER crawleruser
COPY --chown=crawleruser:crawlergroup --chmod=775 . /home/app
WORKDIR /home/app
RUN make clean install

# Clean up build dependencies
RUN rm -r /home/crawleruser/.m2

# Remove ruby-maven and ruby-maven-libs gems, which are only needed at build time
# for JAR dependency resolution. This also removes the bundled plexus-utils-3.5.1.jar
# (CVE-2025-67030) from the production image.
RUN rm -rf /usr/local/bundle/gems/ruby-maven-* \
    /usr/local/bundle/specifications/ruby-maven-* \
    /usr/local/bundle/cache/ruby-maven-*

ENTRYPOINT [ "/bin/bash" ]
