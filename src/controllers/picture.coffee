util = require 'util'
step = require 'step'

app = module.parent.exports
db = app.set 'db'
settings = app.set 'settings'

Pictures = require '../models/pictures'
pictures = new Pictures db

# GET /pictures/album/picture.ext
app.get '/pictures/:album/:picture.:ext', (req, res) ->

  page = req.query.page || 1
  album = req.params.album
  picture = req.params.picture + '.' + req.params.ext

  step(

    # get album
    () ->
      pictures.getPicture album, picture, @
      return undefined

    # render page
    (err, picinfo) ->
      if err then throw err
      if not picture then throw 'Picture not found: ' + album + '/' + picture
      res.render 'picture', {
          locals: {
            pagetitle: picinfo.name
            picture: picinfo
          }
        }

  )

