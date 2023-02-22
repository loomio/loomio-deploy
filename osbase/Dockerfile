# Base osimage for loomio docker images
# it saves a bit of build time
# note to self: to publish this I run commands similar to these:
# docker build . -t loomio/osbase:r276-n14-0
# docker login 
# docker image ls
# docker push loomio/osbase:r276-n14-0

FROM ruby:2.7.6

ENV BUNDLE_BUILD__SASSC=--disable-march-tune-native
ENV MALLOC_ARENA_MAX=2

RUN gem update --system

RUN apt-get update -qq

RUN apt-get install -y autoconf bison patch build-essential rustc libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libgmp-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev uuid-dev sudo git imagemagick ffmpeg mupdf libvips libvips-dev libpng-dev libjpeg-dev libwebp-dev libheif-dev libpq-dev libxml2-dev libxslt1-dev curl python3

RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

# install node

RUN curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
RUN apt-get -y install nodejs
