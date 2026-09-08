if [ ! -f oli.env ]; then
  cp oli.example.env oli.env;

  # use postgres container
  sed -i.bak 's/DB_HOST=/# DB_HOST=/g' oli.env
  rm -f oli.env.bak
  printf "\n\nDB_HOST=postgres" >> oli.env
else
  echo "Config file oli.env already exists. Skipping configuration."
fi