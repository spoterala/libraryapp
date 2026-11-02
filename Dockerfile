# Development image for libraryapp.
# The full ruby image already ships build tools and libpq-dev (needed by the pg gem).
FROM ruby:4.0.9

WORKDIR /rails

# Install gems first so this layer is cached until the Gemfile changes
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4

COPY . .

COPY bin/docker-entrypoint /usr/bin/docker-entrypoint
RUN chmod +x /usr/bin/docker-entrypoint
ENTRYPOINT ["docker-entrypoint"]

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
