ARG ASSETS_BUILDER_IMAGE="node:18.1.0-alpine"
ARG BUILDER_IMAGE="hexpm/elixir:1.13.4-erlang-24.3.4-alpine-3.15.3"
ARG RUNNER_IMAGE="alpine:3.15"

FROM ${ASSETS_BUILDER_IMAGE} as assets-builder

WORKDIR /opt/build

COPY assets/package.json assets/yarn.lock ./assets/

# fetch dependencies
RUN yarn --cwd ./assets

COPY assets assets

ARG NODE_ENV="production"
ENV NODE_ENV="${NODE_ENV}"

# build assets
RUN yarn --cwd ./assets deploy

FROM ${BUILDER_IMAGE} AS builder

RUN apk add --no-cache \
  build-base

# prepare build dir
WORKDIR /opt/build

# install hex + rebar
RUN mix local.hex --force && \
  mix local.rebar --force

ARG app_vsn="0.0.0"
ARG mix_env="prod"

ENV APP_VSN=${app_vsn} \
  MIX_ENV=${mix_env}

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

# note: if your project uses a tool like https://purgecss.com/,
# which customizes asset compilation based on what it finds in
# your Elixir templates, you will need to move the asset compilation
# step down so that `lib` is available.
COPY assets assets
COPY --from=assets-builder --chown=nobody:nobody /opt/build/assets assets

# compile assets
RUN mix assets.esbuild

# Compile the release
COPY lib lib

RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# OLD

# # install mix dependencies
# COPY mix.exs mix.lock ./

# # Ensure we copy deps if we are caching them or fetching them outside the build
# # COPY deps deps

# COPY config config
# RUN mix do deps.get --only prod, deps.compile

# COPY rel rel

# # Copy pre-built assets from previous stage
# COPY --from=assets-builder --chown=nobody:nobody /opt/build/assets assets
# RUN mix phx.digest
# COPY priv priv

# # compile and build release
# COPY lib lib
# RUN mix do compile, release --overwrite

# COPY docker-entrypoint.sh ./
# # Make docker-entrypoint.sh executable
# RUN chmod +x docker-entrypoint.sh

# END - OLD

# prepare release image
FROM ${RUNNER_IMAGE} AS app

RUN apk add --no-cache \
  bash \
  ca-certificates \
  libstdc++ \
  ncurses-libs \
  openssl \
  imagemagick

# # Set the locale
# RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

# ENV LANG en_US.UTF-8
# ENV LANGUAGE en_US:en
# ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /opt/build/_build/prod/rel/safarimanager ./

RUN mkdir /var/safarimanager
RUN chown nobody /var/safarimanager

USER nobody

CMD ["/app/bin/server"]

# WORKDIR /opt/app

# RUN chown nobody:nobody /opt/app

# USER nobody:nobody

# ARG app_vsn="0.0.0"
# ARG mix_env=prod

# ENV APP_VSN=${app_vsn} \
#   MIX_ENV=${mix_env}

# COPY --from=builder --chown=nobody:nobody /opt/build/docker-entrypoint.sh /bin
# COPY --from=builder --chown=nobody:nobody /opt/build/_build/prod/rel/safarimanager ./

# ENV HOME=/opt/app

# ENTRYPOINT ["docker-entrypoint.sh"]
# CMD ["start"]
