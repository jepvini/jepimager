# jepimager

get the artist image for your music collection useing the spotify API

*by jep*

### USAGE
The sript is designed to work in a file structure with `Music/Genre/Artist/Albums/Tracks`
The `Artist` name must have depth equal to 2 related to the argument (`Music` in this case)

- Launch the script, it should exit creating the `.keys.json` file
- Add the api key and the secret key to the file
- Lauch it again, if the music collection is large it could take some time
- The script will create a `.api.json` in every artist folder, containing the id and the artist name
- If there are errors with the matching of an artist edit manually the `.api.json` file putting the right id
- To get it go to spotify -> artist name -> share and paste everything after the `*/artist/` part
- Just re-run the script and it should also fix the name in the `.api.json` file

The idea behind this project is to have a reliable, fast and practical way to manage the artist image
