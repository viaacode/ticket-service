.ONESHELL:
SHELL = /bin/bash

.PHONY: all test

test:
	bundle config set with 'development'
	bundle install
	cd ./app
	mkdir ./tmp
	bundle exec rspec  -r rspec_junit_formatter --format RspecJunitFormatter -o tests/test_results.xml
