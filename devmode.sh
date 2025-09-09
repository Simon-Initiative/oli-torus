#!/bin/bash
echo ""
echo "## Welcome to OLI devmode!"
echo "## This is a convenience environment to help run OLI in development mode natively."
echo "## "

if [ ! -f .devmode ]; then
  echo "## It looks like this is your first time using devmode. Lets gather some prerequisites..." && sleep 1
  mix deps.get
  cd assets && yarn && yarn deploy
  cd ..

  echo "## Creating config files. Using defaults"
  if [ ! -f oli.env ]; then cp oli.example.env oli.env; fi
  if [ ! -f postgres.env ]; then cp postgres.example.env postgres.env; fi

  # set DB_HOST=localhost
  sed -i '' 's/DB_HOST=/# DB_HOST=/g' oli.env
  printf "\n\nDB_HOST=localhost" >> oli.env

  echo "## Starting postgres database..."
  docker compose up -d postgres && sleep 5

  echo "## Creating database and running migration..."
  set -a
  source oli.env
  mix ecto.setup

  touch .devmode
  echo "## All done. Let's write some code!" && sleep 1
  echo "##"
else
  echo "## It looks like you've been here before. Skipping prerequisites."
  echo "##"
fi

# start database if it's not running
if ! docker compose ps | grep -iq "oli_postgres.\+Up"; then
  echo "## Starting postgres database..."
  docker compose up -d postgres && sleep 5
fi

# start minio if it's not running
if ! docker compose ps | grep -iq "minio.\+Up"; then
  echo "## Starting MinIO storage..."
  docker compose up -d minio && sleep 5

  echo "## Setting up MinIO buckets..."
  docker compose exec minio /bin/sh -c "mc alias set localminio http://localhost:9000 your_minio_access_key your_minio_secret_key && mc mb --ignore-existing localminio/torus-media-dev"
  docker compose exec minio /bin/sh -c "mc alias set localminio http://localhost:9000 your_minio_access_key your_minio_secret_key && mc mb --ignore-existing localminio/torus-xapi-dev"
  docker compose exec minio /bin/sh -c "mc alias set localminio http://localhost:9000 your_minio_access_key your_minio_secret_key && mc mb --ignore-existing localminio/torus-blob-dev"

  echo "## Setting MinIO bucket policies..."
  docker compose exec minio /bin/sh -c "mc alias set localminio http://localhost:9000 your_minio_access_key your_minio_secret_key && mc anonymous set public localminio/torus-media-dev"
  docker compose exec minio /bin/sh -c "mc alias set localminio http://localhost:9000 your_minio_access_key your_minio_secret_key && mc anonymous set public localminio/torus-xapi-dev"
  docker compose exec minio /bin/sh -c "mc alias set localminio http://localhost:9000 your_minio_access_key your_minio_secret_key && mc anonymous set public localminio/torus-blob-dev"
fi

echo "## NOTICE: Running 'reload-env' will apply any configuration set in oli.env"
echo "## "
echo "## Use the command 'exit' to leave anytime."
echo "## To get started, run 'mix phx.server'"

ALIASES="alias c=claude --dangerously-skip-permissions; alias dc=docker-compose; alias reload-env='set -a;source oli.env;';"
FUNCTIONS="cd() { builtin cd \"\$@\" && ls; };"
PROMPT="PS1='\n\[\e[0m\]🚧 oli-dev \[\e[0;34m\][\[\e[0;34m\]\w\[\e[0;34m\]]\[\e[0m\] $ \[\e[0m\]';"

{ echo "${ALIASES}${FUNCTIONS}${PROMPT}set -a; source oli.env;"; } > temp_init_file
bash --init-file temp_init_file
rm temp_init_file
