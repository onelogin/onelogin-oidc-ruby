FROM ruby:3.4-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config set --global frozen true

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
