app = require './app'
express = require 'express'
server = express.createServer ()
util = require 'util'
path = require 'path'
fs = require 'fs'


# GET /
server.get '/', (req, res) ->
  page = req.query.page || 1
  app.getAlbums page, (err, albums) ->
    if err then throw err
    app.countAlbums (err, count) ->
      if err then throw err
      res.render 'index', {
          locals: {
            page: page
            albums: albums
            pagination: app.makePagination req.url, Math.ceil(count / app.albumsPerPage)
          }
        }


# GET /albums/album
server.get '/albums/:album', (req, res) ->
  page = req.query.page || 1
  app.getAlbum req.params.album, page, (err, album) ->
    if err then throw err
    app.countPictures album, (err, count) ->
      if err then throw err
      res.render 'album', {
          locals: {
            page: page
            album: album
            pagetitle: album.name
            pagination: app.makePagination req.url, Math.ceil(count / app.picturesPerPage)
          }
        }


# GET /pictures/album/picture.ext
server.get '/pictures/:album/:picture.:ext', (req, res) ->
  album = req.params.album
  picture = req.params.picture + '.' + req.params.ext
  app.getPicture album, picture, (err, picinfo) ->
    if err then throw err
    res.render 'picture', {
        locals: {
          pagetitle: picinfo.name
          picture: picinfo
        }
      }


# GET /thumbs/album/picture.ext
# Create the thumbnail on first request. Subsequent
# requests should be served by nginx with the thumbnail
# generated here.
server.get '/thumbs/:album/:picture.:ext', (req, res) ->
  album = req.params.album
  picture = req.params.picture + '.' + req.params.ext
  filename = path.join app.thumbDir, album, picture
  app.makeThumbnail album, picture, (err) ->
    if err then throw err
    fs.readFile filename, (err, data) ->
      if err then throw err
      headers = { 'Content-Type': 'image/jpeg' }
      res.writeHead 200, headers
      res.write data, 'binary'
      res.end ()


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
        appname: app.appName
        apptitle: app.appTitle
        pagetitle: ''
        pagination: null
        album: null
        picture: null
      }
    # start listening
    server.listen 8124
    util.log 'Application started.'

