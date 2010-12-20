util = require 'util'
step = require 'step'

app = module.parent.exports
db = app.set 'db'
settings = app.set 'settings'

Albums = require '../models/albums'
albums = new Albums db, settings.albumDir


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

    if req.body.rename?
      res.redirect '/albums/rename/' + album
      return
    if req.body.move?
      res.redirect '/albums/move/' + album
      return
    if req.body.delete?
      albums.delete album, (err) ->
        if err then throw err
        res.redirect '/'
      return

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


# GET /albums/rename
app.get '/albums/rename/:album', (req, res) ->

  if req.session.userid

    album = req.params.album

    res.render 'renamealbum', {
        locals: {
          pagetitle: 'Rename Album'
          albumname: album
        }
      }

  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# POST /albums/rename
app.post '/albums/rename', (req, res) ->

  if req.session.userid

    album = req.body.album
    target = req.body.target

    albums.rename album, target, (err) ->
      if err then throw err
      res.redirect '/albums/' + target

  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# GET /albums/move
app.get '/albums/move/:album', (req, res) ->

  if req.session.userid

    album = req.params.album

    res.render 'movealbum', {
        locals: {
          pagetitle: 'Move Album'
          albumname: album
        }
      }

  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# POST /albums/move
app.post '/albums/move', (req, res) ->

  if req.session.userid

    album = req.body.album
    target = req.body.target

    albums.move album, target, (err) ->
      if err then throw err
      res.redirect '/albums/' + target

  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'



