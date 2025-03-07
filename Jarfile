# This file is used to control our Jar dependencies and is used with jar-dependencies to vendor
# our java dependencies into vendor/jars (see https://github.com/mkristian/jar-dependencies for details)
#
# If you update this file, please run the following command to update the jars cache:
#    make clean install
#
# When adding a new dependency, please explain what it is and why we're adding it in a comment.
#---------------------------------------------------------------------------------------------------
# Crawler-Commons is a set of reusable Java components that implement functionality common to any web crawler.
# For now we're only interested in using the robots.txt parsing functionality.
jar 'com.github.crawler-commons:crawler-commons', '1.2'

# Apache HTTP client used by the crawler
jar 'org.apache.httpcomponents.client5:httpclient5', '5.1'

#---------------------------------------------------------------------------------------------------
# Text extraction and other utilities
jar 'org.apache.tika:tika-parsers', '1.28.5'
jar 'org.apache.commons:commons-lang3', '3.10'

#---------------------------------------------------------------------------------------------------
# Indirect dependencies that we needed to upgrade
jar 'com.github.junrar:junrar', '7.4.1'
jar 'org.jsoup:jsoup', '1.14.3'
jar 'commons-io:commons-io', '2.11.0'
jar 'org.apache.cxf:cxf-rt-transports-http', '3.4.10'
jar 'org.apache.cxf:cxf-core', '3.4.10'
jar 'com.mchange:c3p0', '0.9.5.4'
jar 'org.apache.commons:commons-compress', '1.21'
jar 'com.fasterxml.jackson.core:jackson-databind', '2.14.2'
jar 'com.fasterxml.woodstox:woodstox-core', '6.5.1'
jar 'com.google.guava:guava', '32.1.3-jre'
