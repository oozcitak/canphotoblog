app = require './app'
cutil = require './util'
express = require 'express'
server = express.createServer ()
util = require 'util'
path = require 'path'


# GET /
server.get '/', (req, res) ->
  page = req.query.page || 1
  app.albums.getAlbums page, app.settings.albumsPerPage, (err, albums) ->
    if err then throw err
    app.albums.countAlbums (err, count) ->
      if err then throw err
      res.render 'index', {
          locals: {
            page: page
            albums: albums
            pagination: cutil.makePagination req.url, Math.ceil(count / app.settings.albumsPerPage)
          }
        }


# GET /albums/album
server.get '/albums/:album', (req, res) ->
  page = req.query.page || 1
  app.albums.getAlbum req.params.album, page, app.settings.picturesPerPage, (err, album) ->
    if err then throw err
    if not album then throw 'Album not found: ' + req.params.album
    app.albums.countPictures album, (err, count) ->
      if err then throw err
      res.render 'album', {
          locals: {
            page: page
            album: album
            pagetitle: album.name
            pagination: cutil.makePagination req.url, Math.ceil(count / app.settings.picturesPerPage)
          }
        }


# GET /pictures/album/picture.ext
server.get '/pictures/:album/:picture.:ext', (req, res) ->
  album = req.params.album
  picture = req.params.picture + '.' + req.params.ext
  app.pictures.getPicture album, picture, (err, picinfo) ->
    if err then throw err
    if not picture then throw 'Picture not found: ' + req.params.album
    res.render 'picture', {
        locals: {
          pagetitle: picinfo.name
          picture: picinfo
        }
      }


# Errors
server.error (err, req, res) ->
  util.log err
  res.render '500', {
      layout: false,
      locals: { message: err.message }
    }


# 404
server.get '*', (req, res) ->
  util.log '404: ' + req.url
  res.render '404', {
      layout: false
    }


# Init application
app.init (err) ->
  if err then throw err
  server.configure () ->
    server.set 'view engine', 'haml'
    server.set 'views', path.join(path.dirname(__dirname), 'views')
    server.helpers {
        appname: app.settings.appName
        apptitle: app.settings.appTitle
        pagetitle: ''
        pagination: null
        album: null
        picture: null
        gaKey: app.settings.gaKey
      }
    # start listening
    server.listen 8124
    util.log 'Application started.'

