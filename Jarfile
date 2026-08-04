# This file is used to control our Jar dependencies and is used with jar-dependencies to vendor
# our java dependencies into vendor/jars (see https://github.com/mkristian/jar-dependencies for details)
#
# If you update this file, please run the following command to update the jars cache:
#    make clean install
#
# When adding a new dependency, please explain what it is and why we're adding it in a comment.

# Functionality common to any web crawler
jar 'com.github.crawler-commons:crawler-commons', '1.2'

# Pinned dependency of crawler-commons to resolve vulnerability (updated to 2.16.1 for commons-compress compatibility)
jar 'commons-io:commons-io', '2.16.1'

# Apache HTTP client used for requests to websites
# Pinned to 5.6.2+ to pull in httpcore5/httpcore5-h2 5.4.3, resolving
# CVE-2025-8671, CVE-2026-54399, and CVE-2026-54428 (HTTP DoS in httpcore5-h2).
jar 'org.apache.httpcomponents.client5:httpclient5', '5.6.2'

# For managing Brotli input streams
jar 'org.apache.commons:commons-compress', '1.27.1'
# Pinned transitive of commons-compress to resolve CVE-2025-48924 (uncontrolled recursion)
jar 'org.apache.commons:commons-lang3', '3.18.0'
jar 'org.brotli:dec', '0.1.2'

# for parsing HTML
jar 'org.jsoup:jsoup', '1.20.1'

# Cleaner Java logs handling
jar 'org.slf4j:slf4j-nop', '1.7.26'
