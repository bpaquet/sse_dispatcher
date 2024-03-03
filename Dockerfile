ARG BUILDER_IMAGE=elixir:1.16.1-slim

FROM ${BUILDER_IMAGE} as builder

RUN mkdir /app
WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force

COPY mix.exs mix.lock /app/
RUN mix deps.get

COPY lib /app/lib/

RUN mix release sse_dispatcher

FROM ${BUILDER_IMAGE}

RUN mkdir /app
WORKDIR /app

COPY priv /app/priv/
COPY --from=builder /app/_build/prod/rel/sse_dispatcher /app

CMD [ "/app/bin/sse_dispatcher", "start" ]