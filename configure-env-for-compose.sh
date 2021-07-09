#!/bin/bash

cp postgres.example.env postgres.env
cp oli.example.env oli.env
sed -i'' 's/DB_HOST=/# DB_HOST=/g' oli.env
sed -i'' 's/FRESHDESK_API_URL=/# FRESHDESK_API_URL=/g' oli.env
printf "\n\nDB_HOST=postgres" >> oli.env
