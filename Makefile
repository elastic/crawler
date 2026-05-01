.phony: test lint autocorrect install install-ci install-gems install-jars clean notice build-docker-ci build-docker-wolfi list-gems list-jars push

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

build-docker-wolfi:
	docker build -t crawler-ci-wolfi -f Dockerfile.wolfi .

push:
	docker tag crawler-ci corgicloud/crawler:tagname
	docker push corgicloud/crawler:tagname

list-gems:
	script/bundle exec gem dependency

list-jars:
	script/bundle exec lock_jars --tree
