.phony: test lint autocorrect install install-ci install-gems install-jars clean notice build-docker-ci list-gems list-jars

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
	script/bundle exec script/vendor_jars

clean:
	rm -rf Jars.lock vendor/jars

notice:
	script/licenses/generate_notice.rb

build-docker-ci:
	docker build -t crawler-ci .

list-gems:
	script/bundle exec gem dependency

list-jars:
	script/bundle exec lock_jars --tree
