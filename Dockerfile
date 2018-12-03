FROM unicorn:latest

ADD app /app

RUN bash -l -c "cd /app && bundle install"

RUN echo 'working_directory "/app"' >/home/unicorn/unicorn.conf

CMD [ "unicorn -c /home/unicorn/unicorn.conf" ]

