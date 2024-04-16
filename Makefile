JAVA_VERSION := $(shell cat .java-version)
JAVA_HOME := $(shell jenv prefix $(JAVA_VERSION))

lint:
	rubocop

autoformat:
	rubocop --autocorrect

install:
	script/bundle install && exec script/vendor_jars

clean:
	rm -rf Jars.lock vendor/jars
