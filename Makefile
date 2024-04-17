JAVA_VERSION := $(shell cat .java-version)
JAVA_HOME := $(shell jenv prefix $(JAVA_VERSION))
.phony: lint autocorrect install install-ci install-gems install-jars clean

lint:
	rubocop

autocorrect:
	rubocop --autocorrect

install:
	script/environment
	make install-gems
	make install-jars

install-ci:
	make install-gems
	make install-jars

install-gems:
	script/bundle install

install-jars:
	script/bundle exec script/vendor_jars

clean:
	rm -rf Jars.lock vendor/jars
