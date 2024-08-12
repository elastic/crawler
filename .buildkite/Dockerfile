FROM jruby:9.4.8.0-jdk21@sha256:1bd52573fb0e9f5dda74a41e0becd9fe6c83517867feff87e5aff92bc82bdcf5
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libicu-dev netbase make

ENTRYPOINT [ "/bin/bash" ]
