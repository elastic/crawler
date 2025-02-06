.phony: test lint autocorrect install install-ci install-gems install-jars clean notice build-docker-ci

test:
	script/rspec $(file)

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
	script/vendor_jars

clean:
	rm -rf Jars.lock vendor/jars

notice:
	script/licenses/generate_notice.rb

build-docker-ci:
	docker build -t crawler-ci .
