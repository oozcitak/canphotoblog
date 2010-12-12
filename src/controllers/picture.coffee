fs = require 'fs'
path = require 'path'
util = require 'util'
step = require 'step'
im = require '../libs/img'

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
      if not picinfo then throw 'Picture not found: ' + album + '/' + picture
      res.render 'picture', {
          locals: {
            pagetitle: picinfo.name
            picture: picinfo
          }
        }

  )


# GET /thumbs/album/picture.ext
# Create the thumbnail on first request. Subsequent
# requests should be served by nginx with the thumbnail
# generated here.
app.get '/thumbs/:album/:picture.:ext', (req, res) ->

  page = req.query.page || 1
  album = req.params.album
  picture = req.params.picture
  ext = req.params.ext
  source = path.join settings.albumDir, album, picture + '.jpg'
  dest = path.join settings.thumbDir, album, picture + '.png'

  step(

    # get thumbnail
    () ->
      im.makeThumbnail source, dest, settings.thumbSize, @
      return undefined

    # read image
    (err) ->
      if err then throw err
      fs.readFile dest, @
      return undefined

    # output image
    (err, data) ->
      if err then throw err
      headers = {
        'Content-Type': 'image/jpeg'
        'Content-Length': data.length
      }
      res.writeHead 200, headers
      res.write data, 'binary'
      res.end()

  )

