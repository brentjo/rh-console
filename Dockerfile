FROM ruby:2.7.1

RUN mkdir /rh-console
WORKDIR /rh-console
COPY . /rh-console

CMD ["bin/rh-console"]
