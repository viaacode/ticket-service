FROM ruby:3

RUN bundle config set without 'development'
# The app's Gemfile does not contain the HTTP server gem.
# Because this is an implementation detail which is not part of the app. 
# The app is designed to run on top of any rack compatible HTTP server.
# Here we install unicorn and set the bundle config system to true such that
# the bundled gems blend in with the unicorn gem.
# In other words, it allows to add the unicorn gem without altering the Gemfile
RUN bundle config set system 'true' && gem install unicorn
ENTRYPOINT [ "unicorn" ]
CMD [ "-E", "production", "-c", "/unicorn.conf" ]
RUN echo "worker_processes 4" >/unicorn.conf

# At this point we have a generic unicorn container.
ADD Gemfile /
ADD Gemfile.lock /
RUN bundle install

ADD config.ru /
ADD app /app

