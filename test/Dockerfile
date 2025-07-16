FROM bats/bats

RUN \ 
  apk \
    --no-cache \
    --update \
    add \
      git \
  && \
  git config --system --add safe.directory '*'
