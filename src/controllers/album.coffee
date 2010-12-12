util = require 'util'
step = require 'step'

app = module.parent.exports
db = app.set 'db'
settings = app.set 'settings'

Albums = require '../models/albums'
albums = new Albums db

# GET /albums/album
app.get '/albums/:album', (req, res) ->

  page = req.query.page || 1
  album = req.params.album

  step(

    # get album
    () ->
      albums.getAlbum album, page, settings.picturesPerPage, @parallel()
      albums.countPictures album, @parallel()
      return undefined

    # render page
    (err, item, count) ->
      if err then throw err
      if not item then throw 'Album not found: ' + album

      res.render 'album', {
          locals: {
            page: page
            album: item
            pagetitle: item.name
            pageCount: Math.ceil(count / settings.picturesPerPage)
          }
        }

  )

