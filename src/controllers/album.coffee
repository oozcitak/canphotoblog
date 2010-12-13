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
      albums.getAlbum album, page, settings.picturesPerPage, @
      return undefined

    # render page
    (err, item) ->
      if err then throw err
      if not item then throw new Error('Album not found: ' + album)

      app.helpers { pageCount: Math.ceil(item.count / settings.albumsPerPage) }

      res.render 'album', {
          locals: {
            album: item
            pagetitle: item.name
          }
        }

  )


# POST /albums/edit
app.post '/albums/edit', (req, res) ->

  if req.session.userid
    album = req.body.album
    title = req.body.title
    text = req.body.text

    step(

      # edit album
      () ->
        albums.editAlbum album, title, text, @
        return undefined

      # go back
      (err, item) ->
        if err then throw err
        res.redirect '/albums/' + album

    )

  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'

