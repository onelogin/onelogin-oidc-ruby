FROM ruby:2.5.0

RUN \
    apt-get update && \
    apt-get install -y nodejs

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

CMD bundle exec rails s -b 0.0.0.0 -p 3000
