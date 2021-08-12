.ONESHELL:
SHELL = /bin/bash

.PHONY: all test

test:
	bundle install --with=development
	mkdir tmp
	bundle exec rspec