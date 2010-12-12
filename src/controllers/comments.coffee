util = require 'util'
step = require 'step'

app = module.parent.exports
db = app.set 'db'
settings = app.set 'settings'

Comments = require '../models/comments'
comments = new Comments db


# POST /comments/add
app.post '/comments/add', (req, res) ->
  album = req.body.album
  picture = req.body.picture or null
  name = req.body.from
  text = req.body.text

  if picture
    comments.addToPicture album, picture, name, text, req, (err) ->
      res.redirect '/pictures/' + album + '/' + picture
  else
    comments.addToAlbum album, name, text, req, (err) ->
      res.redirect '/albums/' + album
 
