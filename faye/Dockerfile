FROM ruby:2.3.0

COPY Gemfile.lock Gemfile private_pub.ru /loomio-faye/
WORKDIR /loomio-faye
RUN bundle install

CMD thin --port 4443 \
         --environment production \
         --rackup private_pub.ru \
         start
