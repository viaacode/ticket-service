FROM unicorn:latest

ADD app /app
ADD config.ru /
ADD Gemfile /
ADD Gemfile.lock /

RUN bundle install --without=development

RUN echo "worker_processes 4" >/unicorn.conf

CMD [ "-E", "production", "-c", "/unicorn.conf" ]
