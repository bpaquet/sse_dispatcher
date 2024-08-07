ARG BUILDER_IMAGE=elixir:1.16.1-slim

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates

RUN mkdir /app
WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force

COPY mix.exs mix.lock /app/
RUN mix deps.get

COPY config /app/config/
COPY lib /app/lib/

RUN mix release

FROM ${BUILDER_IMAGE}

RUN apt-get update \
  && apt-get install -y --no-install-recommends haproxy curl dnsutils

RUN mkdir /app
WORKDIR /app

COPY start.sh /start.sh
COPY haproxy.cfg /haproxy.cfg
COPY priv /app/priv/
COPY --from=builder /app/_build/prod/rel/sse_dispatcher /app/

ENV RELEASE_TMP=/tmp/
ENV RELEASE_COOKIE=changme

CMD ["/start.sh" ]