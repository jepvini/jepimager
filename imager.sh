#!/usr/bin/env bash

# jep-imager

# help

if [ "$1" = "-h" ];
then
  echo "jep-imager"
  echo "  -t    generate token and exit"
  echo "  -s    sync the id of a \$2 folder"
  echo "  -f    find the id of a \$2 folder"
  echo "  -a    get the image of a \$2 folder"
  echo "  -h    this menu"
  echo "  --find-all   match all names in folder \$2"
  echo "  --find-deep  shows 10 best match for name \$2"

  exit
fi

# functions

# $1 should be the dir with the artist name

function update_image {
  id="$(jq -r ".id" "$1".api.json)"
  name="$(jq -r ".name" "$1".api.json)"
  info="$(curl -s --request GET \
      --url https://api.spotify.com/v1/artists/"$id" \
    --header "Authorization: Bearer $TOKEN")"
  image="$(echo "$info" \
    | jq -r ".images.[0].url")"

  if [ "$image" = "null" ]; then
    echo "error getting the image for $(jq -r ".name" "$1".api.json)"
    return 1
  fi

  if curl -s "$image" > "$1"/artist.jpeg ;
  then
    echo "updated $name"
  fi
}

function sync_id {
  id="$(jq -r ".id" "$1".api.json)"
  info="$(curl -s --request GET \
      --url https://api.spotify.com/v1/artists/"$id" \
    --header "Authorization: Bearer $TOKEN")"

  id="$(echo "$info" \
  | jq -r ".id")"

  name="$(echo "$info" \
  | jq -r ".name")"

  jq --null-input "{\"name\":\"$name\", \"id\":\"$id\"}" > "$1".api.json
}


function find_id {
  NAME="$(grep -o -P "[^\/]+\/$" <<< "$1" | grep -o -P "[^\/]+")" # Extract name from path
  NAME_SANE=${NAME//,/"%2c"}
  NAME_SANE=${NAME_SANE//&/"%26"}
  NAME_SANE=${NAME_SANE// /"%20"}
  info="$(curl -s --request GET \
    --url "https://api.spotify.com/v1/search?q=$NAME_SANE&type=artist&limit=1" \
  --header "Authorization: Bearer $TOKEN")"

  id="$(echo "$info" \
  | jq -r ".artists.items.[].id")"

  name="$(echo "$info" \
  | jq -r ".artists.items.[].name")"

  echo "--- $NAME matched with $name"

  jq --null-input "{\"name\":\"$name\", \"id\":\"$id\"}" > "$1"/.api.json
}

function find_id_deep {
  NAME="$(grep -o -P "[^\/]+\/$" <<< "$1" | grep -o -P "[^\/]+")" # Extract name from path
  NAME_SANE=${NAME//,/"%2c"}
  NAME_SANE=${NAME_SANE//&/"%26"}
  NAME_SANE=${NAME_SANE// /"%20"}
  info="$(curl -s --request GET \
    --url "https://api.spotify.com/v1/search?q=$NAME_SANE&type=artist&limit=10" \
  --header "Authorization: Bearer $TOKEN")"

  for i in $(seq 0 10);
  do
    echo "$(echo "$info" | jq -r ".artists.items.[$i].name") - $(echo "$info" | jq -r ".artists.items.[$i].id")"
  done
  exit
}

function find_all {
  for dir in "$1"/*/
  do
    find_id "$dir"
  done
}

function update_all {
  for dir in "$1"/*/
  do
    update_image "$dir"
  done
}

# token

# if the keys file does not exist it will create a sample one
if [ ! -f ".keys.json" ];
then
  echo "no .keys.json file found"
  echo "creating one"
  jq --null-input '{"CLIENT_ID":"", "CLIENT_SECRET":"","FORCE_WRITE":"0", "LIMIT":"20", "DEFAULT_DIR":""}' > .keys.json
  exit
fi

# creates the token if it does not exist
if [ ! -f ".token" ];
then
  CLIENT_ID="$(< .keys.json jq -r ".CLIENT_ID")"
  CLIENT_SECRET="$(< .keys.json jq -r ".CLIENT_SECRET")"

  echo "Getting the token..."
  TOKEN="$(curl -s -X POST "https://accounts.spotify.com/api/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET" \
      | jq -r ".access_token")"

  if [ "$TOKEN" = "null" ]; then
    echo "error getting the token"
    echo "check the credentials in .keys.json"
    echo "exiting..."
    exit
  fi
  echo "$TOKEN" > ".token"
fi

TOKEN="$(cat ".token")"

# tests if the token works
test="$(curl -s --request GET \
      --url "https://api.spotify.com/v1/search?q=DavidBowie&type=artist&limit=1" \
    --header "Authorization: Bearer $TOKEN")"

# if it doesn't it will delete it and rerunning the script will create a fresh one
if grep -q error <<< "$test"
then
  rm ".token"
  echo "token expired, please run again the script"
  exit
fi

# args

DIR="$2/"

if [ "$1" = "-t" ];
then
  exit
elif [ "$1" = "-f" ];
then
  find_id "$DIR"
elif [ "$1" = "-s" ];
then
  sync_id "$DIR"
elif [ "$1" = "-a" ];
then
  update_image "$DIR"
elif [ "$1" = "--find-deep" ];
then
  find_id_deep "$DIR"
elif [ "$1" = "--find-all" ];
then
  find_all "$DIR"
elif [ -z "$1" ];
then
  DIR="$(< .keys.json jq -r ".DEFAULT_DIR")"
  if [ -n "$DIR" ];
  then
    if [ ! -d "$DIR" ];
    then
      echo "invalid folder in .keys.json file"
      echo "exiting..."
      exit
    fi
  fi
  update_all "$DIR"
else
  update_all "$1"
fi

# # stats
#
# songs_number="$(find "$DIR" -mindepth 3 -maxdepth 3 -type f | grep -E -c "flac|mp3|wav|dsd|dsf")"
# flac_number="$(find "$DIR" -mindepth 3 -maxdepth 3 -type f | grep -E -c "flac")"
# mp3_number="$(find "$DIR" -mindepth 3 -maxdepth 3 -type f | grep -E -c "mp3")"
# wav_number="$(find "$DIR" -mindepth 3 -maxdepth 3 -type f | grep -E -c "wav")"
# dsd_number="$(find "$DIR" -mindepth 3 -maxdepth 3 -type f | grep -E -c "dsd")"
#
# images_number="$(find "$DIR" -mindepth 2 -maxdepth 2 -type f | grep -E -c "jpeg")"
# errors="$(find "$DIR" -mindepth 2 -maxdepth 2 -type f -size -1k | grep -E "jpeg")"
# echo
# echo "Done"
# echo "$images_number images set"
#
# if [ -n "$errors" ];
# then
#   echo " Unfortunately some jpeg file are empty, check the id in the .api.json file"
#   echo "$errors"
#   echo
# fi
#
# echo "BTW you have $songs_number songs"
# if [ "$flac_number" -gt 0 ]; then
#   echo "flacs: $flac_number"
# fi
# if [ "$mp3_number" -gt 0 ]; then
#   echo "mp3s: $mp3_number"
# fi
# if [ "$wav_number" -gt 0 ]; then
#   echo "wavs: $wav_number"
# fi
# if [ "$dsd_number" -gt 0 ]; then
#   echo "dsd: $dsd_number"
# fi
