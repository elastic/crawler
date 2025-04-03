FROM jruby:9.4.8.0-jdk21@sha256:1bd52573fb0e9f5dda74a41e0becd9fe6c83517867feff87e5aff92bc82bdcf5
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

ENTRYPOINT [ "/bin/bash" ]
