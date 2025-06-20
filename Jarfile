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
jar 'org.apache.httpcomponents.client5:httpclient5', '5.1'

# For loading dynamic content
jar 'org.htmlunit:htmlunit', '4.5.0'

# This version is required for HtmlUnit
jar 'org.apache.httpcomponents:httpclient', '4.5.14'

# For managing Brotli input streams
jar 'org.apache.commons:commons-compress', '1.27.1'
jar 'org.brotli:dec', '0.1.2'

# Cleaner Java logs handling
jar 'org.slf4j:slf4j-nop', '1.7.26'
