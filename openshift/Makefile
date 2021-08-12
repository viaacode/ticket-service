.ONESHELL:
SHELL = /bin/bash

.PHONY: all test

test:
	bundle install --with=development
	cd ./app
	bundle exec rspec  -r rspec_junit_formatter --format RspecJunitFormatter -o tests/test_results.xml