#!/usr/bin/env bash

#####################################################################################################
#                                                                                                   #
#                                         Token management                                          #
#                                                                                                   #
#####################################################################################################

# if the file does not exist it will create a sample one
if [ ! -f ".conf.json" ];
then
  echo "no .conf.json file found"
  echo "creating one"
  jq --null-input '{"CLIENT_ID":"", "CLIENT_SECRET":"","FORCE_WRITE":"0", "LIMIT":"20", "DEFAULT_DIR":""}' > .conf.json
  exit
fi

# check if there is a token already created
TOKEN="$([ -f ".token" ] && cat ".token")"

# creates the token if it does not exist
if [ ! -f ".token" ];
then
  CLIENT_ID="$(< .keys.json jq ".CLIENT_ID" | sed "s/\"//g")"
  CLIENT_SECRET="$(< .keys.json jq ".CLIENT_SECRET" | sed "s/\"//g")"
  TOKEN="$(curl -s -X POST "https://accounts.spotify.com/api/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET" \
    | jq ".access_token" \
    | sed "s/\"//g")"

  echo "Getting the token..."
  echo "$TOKEN" > ".token"
fi

# tests if the token works
test="$(curl -s --request GET \
    --url "https://api.spotify.com/v1/search?q=DavidBowie&type=artist&limit=1" \
    --header "Authorization: Bearer $TOKEN")"


# if it doesn't it will delete it and rerunnng the script will create a fresh one
if [ "$(grep  error <<< "$test")" ];
then
  rm ".token"
  echo "token expired, please run again the script"
  exit
fi



#####################################################################################################
#                                                                                                   #
#                                           Arg management                                          #
#                                                                                                   #
#####################################################################################################

# The script can be launched without a folder to set the token
if [ -z "$1" ];
then
  DIR="$(< .conf.json jq ".DEFAULT_DIR" | sed "s/\"//g")"
  if [ -n "$DIR" ];
  then
    if [ ! -d "$DIR" ];
    then
      echo "invalid folder in .conf.json file"
      exit
    fi
  else
    echo "provide the folder name"
    exit
  fi
else
  DIR="$1"
fi



#####################################################################################################
#                                                                                                   #
#                                       Specific folder option                                      #
#                                                                                                   #
#####################################################################################################

if [ "$1" = "-a" ];
then
  if [ -z "$2" ];
  then
    echo "provide the folder"
    exit
  fi
  dir="${2%*/}"
  dir_nospaces="${dir##*/}"
  echo "$dir_nospaces"
  # echo "$dir"
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

  exit
fi

#####################################################################################################
#                                                                                                   #
#                                           Loop over folders                                       #
#                                                                                                   #
#####################################################################################################

songs_number="$(find "$DIR" -mindepth 3 -maxdepth 3 -type f | grep -E -c "flac|mp3|wav|dsd|dsf")"
if [ "$songs_number" -lt 10 ]; # arbitrary number
then
  echo "No music file found, check that your file structure is Music/Artists/Albums/Songs"
  echo "Exting"
  exit
fi

for dir in "$DIR"/*/
do
  dir="${dir%*/}"
  dir_nospaces="${dir##*/}"
  # echo "$dir_nospaces"
  dir_nospaces="${dir_nospaces// /}"
  echo "$dir"
  echo "$dir_nospaces"
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

images_number="$(find "$DIR" -mindepth 2 -maxdepth 2 -type f | grep -E -c "jpeg")"
errors="$(find "$DIR" -mindepth 2 -maxdepth 2 -type f -size -1k | grep -E "jpeg")"
echo
echo "Done"
echo "$images_number images set"

if [ -n "$errors" ];
then
  echo " Unfortunately some jpeg file are empty, check the id in the .api.json file"
  echo "$errors"
  echo
fi

echo "BTW you have $songs_number songs"
