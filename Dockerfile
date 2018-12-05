FROM unicorn:latest

ADD app /app
ADD config.ru /
ADD Gemfile /
ADD Gemfile.lock /

RUN bash -l -c "bundle install"

CMD [ "unicorn" ]

