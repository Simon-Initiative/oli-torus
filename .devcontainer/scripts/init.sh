if [ ! -f oli.env ]; then
  cp oli.example.env oli.env;

  # use postgres container
  sed -i '' 's/DB_HOST=/# DB_HOST=/g' oli.env
  printf "\n\nDB_HOST=postgres" >> oli.env
else
  echo "## oli.env config already exists. Skipping config setup."
  echo "##"
fi