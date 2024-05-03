.phony: test lint autocorrect install install-ci install-gems install-jars clean build-docker-ci

test:
	script/rspec $(file)

lint:
	rubocop

autocorrect:
	rubocop --auto-correct

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
	script/vendor_jars

clean:
	rm -rf Jars.lock vendor/jars

build-docker-ci:
	docker build -t crawler-ci .buildkite
