#!/usr/bin/env bash

if [ -z "$1" ];
then
  echo "provide the folder name"
  exit
fi

if [ ! -f ".keys.json" ];
then
  echo "no .keys.conf file found"
  echo "creating one"
  jq --null-input '{"CLIENT_ID":"", "CLIENT_SECRET":"","FORCE_WRITE":"0", "LIMIT":"20", "TOKEN":""}' > .keys.json
  exit
fi

TOKEN="$([ -f ".token" ] && cat ".token")"
FORCE_WRITE="$(< .keys.json jq ".FORCE_WRITE" | sed "s/\"//g")"

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

test="$(curl --request GET \
    --url "https://api.spotify.com/v1/search?q=DavidBowie&type=artist&limit=1" \
    --header "Authorization: Bearer $TOKEN")"


if [ "$(grep  error <<< "$test")" ];
then
  rm ".token"
  echo "token expired, please lunch again"
  exit
fi

for dir in "$1"/*/*/
do
  dir="${dir%*/}" # remove the trailing "/"
  dir_nospaces="${dir##*/}" # print everything after the final "/"
  dir_nospaces="${dir_nospaces// /}"
  echo $dir_nospaces
  id="$([ -f "$dir"/.api.json ] && (cat "$dir"/.api.json | jq ".id" | sed "s/\"//g"))"
  if [ -n "$id" ];
  then
    info="$(curl --request GET \
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

    curl "$image" > "$dir"/artist.jpeg
    jq --null-input "{\"name\":\"$name\", \"id\":\"$id\"}" > "$dir"/.api.json
  else
    info="$(curl --request GET \
            --url "https://api.spotify.com/v1/search?q=$dir_nospaces&type=artist&limit=1" \
            --header "Authorization: Bearer $TOKEN")"


    if [ "$(grep  error <<< "$info")" ];
    then
      rm ".token"
      echo "token expired, please lunch again"
      exit
    fi

    id="$(echo "$info" \
            | jq ".artists.items.[].id" \
            | sed "s/\"//g")"

    name="$(echo "$info" \
            | jq ".artists.items.[].name" \
            | sed "s/\"//g")"

    image="$(echo "$info" \
            | jq ".artists.items.[].images.[0].url" \
            | sed "s/\"//g")"

    curl "$image" > "$dir"/artist.jpeg
    jq --null-input "{\"name\":\"$name\", \"id\":\"$id\"}" > "$dir"/.api.json

  fi
done
