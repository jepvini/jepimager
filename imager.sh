#!/usr/bin/env bash

if [ -z "$1" ];
then
  echo "provide the folder name"
  exit
fi

if ! find "$1" -mindepth 4 -maxdepth 4 -type f | grep -E "flac|mp3|wav|dsd|dsf" 1>/dev/null
then
  echo "No music file found, check that your file structure is Music/Genres/Artists/Albums/Songs"
  echo "Exting"
  exit
fi

if [ "$1" = "-a" ];
then
  echo
fi

#
# Token management
#
if [ ! -f ".keys.json" ];
then
  echo "no .keys.conf file found"
  echo "creating one"
  jq --null-input '{"CLIENT_ID":"", "CLIENT_SECRET":"","FORCE_WRITE":"0", "LIMIT":"20", "TOKEN":""}' > .keys.json
  exit
fi

TOKEN="$([ -f ".token" ] && cat ".token")"

if [ ! -f ".token" ];
then
  CLIENT_ID="$(< .keys.json jq ".CLIENT_ID" | sed "s/\"//g")"
  CLIENT_SECRET="$(< .keys.json jq ".CLIENT_SECRET" | sed "s/\"//g")"
  TOKEN="$(curl -X POST "https://accounts.spotify.com/api/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET" \
    | jq ".access_token" \
    | sed "s/\"//g")"

  echo "$TOKEN" > ".token"
fi

test="$(curl -s --request GET \
    --url "https://api.spotify.com/v1/search?q=DavidBowie&type=artist&limit=1" \
    --header "Authorization: Bearer $TOKEN")"

name="$(echo "$test" \
              | jq ".artists.items.[].name" \
              | sed "s/\"//g")"

if [ "$(grep  error <<< "$name")" ];
then
  rm ".token"
  echo "token expired, please lunch again"
  exit
fi

#
# loop over folders
#

for dir in "$1"/*/*/
do
  dir="${dir%*/}"
  dir_nospaces="${dir##*/}"
  echo "$dir_nospaces"
  dir_nospaces="${dir_nospaces// /}"
  id="$([ -f "$dir"/.api.json ] && (cat "$dir"/.api.json | jq ".id" | sed "s/\"//g"))"
  if [ -n "$id" ];
  then
    info="$(curl -s --request GET \
        --url https://api.spotify.com/v1/artists/"$id" \
        --header "Authorization: Bearer $TOKEN")"

    image="$(echo "$info" \
              | jq ".images.[0].url" \
              | sed "s/\"//g")"

    name="$(echo "$info" \
              | jq ".name" \
              | sed "s/\"//g")"

    id="$(echo "$info" \
              | jq ".id" \
              | sed "s/\"//g")"

    curl -s "$image" > "$dir"/artist.jpeg
    jq --null-input "{\"name\":\"$name\", \"id\":\"$id\"}" > "$dir"/.api.json
  else
    info="$(curl -s --request GET \
              --url "https://api.spotify.com/v1/search?q=$dir_nospaces&type=artist&limit=1" \
              --header "Authorization: Bearer $TOKEN")"

    id="$(echo "$info" \
              | jq ".artists.items.[].id" \
              | sed "s/\"//g")"

    name="$(echo "$info" \
              | jq ".artists.items.[].name" \
              | sed "s/\"//g")"

    image="$(echo "$info" \
              | jq ".artists.items.[].images.[0].url" \
              | sed "s/\"//g")"

    curl -s "$image" > "$dir"/artist.jpeg
    jq --null-input "{\"name\":\"$name\", \"id\":\"$id\"}" > "$dir"/.api.json

  fi
done
