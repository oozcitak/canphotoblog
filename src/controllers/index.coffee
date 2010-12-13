util = require 'util'
path = require 'path'
step = require 'step'

app = module.parent.exports
db = app.set 'db'
settings = app.set 'settings'

Albums = require '../models/albums'
albums = new Albums db

# GET /
app.get '/', (req, res) ->

  page = req.query.page || 1

  step(

    # get all albums
    () ->
      albums.getAlbums page, settings.albumsPerPage, @parallel()
      albums.countAlbums @parallel()
      return undefined

    # render page
    (err, rows, count) ->
      if err then throw err

      app.helpers { pageCount: Math.ceil(count / settings.albumsPerPage) }

      res.render 'index', {
          locals: {
            albums: rows
          }
        }

  )
