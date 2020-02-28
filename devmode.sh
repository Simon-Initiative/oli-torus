echo ""
echo "## Welcome to OLI devmode!"
echo "## This is a convenience environment to help run OLI in development mode natively."
echo "## "

if [ ! -f .devmode ]; then
  echo "## Looks like this is your first time using devmode. Lets gather some prerequisites..." && sleep 1
  mix deps.get
  cd assets && npm install
  cd ..

  echo "## Creating config files. Using defaults"
  if [ ! -f oli.env ]; then cp oli.example.env oli.env; fi
  if [ ! -f postgres.env ]; then cp postgres.example.env postgres.env; fi

  # set DB_HOST=localhost
  sed -i '' 's/DB_HOST=/# DB_HOST=/g' oli.env
  printf "\n\nDB_HOST=localhost" >> oli.env

  echo "## Starting postgres database..."
  docker-compose up -d postgres && sleep 5

  echo "## Creating database and running migration..."
  mix ecto.create
  mix ecto.migrate

  touch .devmode
  echo "## All done. Let's write some code!" && sleep 1
  echo "##"
else
  echo "## Looks like you've been here before. Skipping prerequisites."
  echo "##"
fi

echo "## NOTICE: If you make changes to oli.env, you must re-source the file for changes to be applied:"
echo "##  $ source oli.env"
echo "##  $ mix phx.server"
echo "## "
echo "## Use the command 'exit' to leave anytime."
echo ""

bash -c "source oli.env;PS1=\"🚧 oli-dev \033[0;34m[\w]\033[0;37m $ \" bash --norc"