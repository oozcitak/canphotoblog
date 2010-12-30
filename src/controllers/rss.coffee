util = require 'util'
path = require 'path'
step = require 'step'
url = require 'url'
cutil = require '../libs/util'

app = module.parent.exports.expressApp
db = app.set 'db'
settings = app.set 'settings'

Albums = require '../models/albums'
albums = new Albums db, settings.albumDir


# GET /rss
app.get '/rss', (req, res) ->

  step(

    # get all albums
    () ->
      albums.getAlbums 1, settings.albumsPerPage, @
      return undefined

    # render page
    (err, rows) ->
      if err then throw err

      parts = { protocol: 'http:', host: req.headers.host }
      appurl = url.format(parts)

      for i in [0...rows.length]
        rows[i].dateCreated = cutil.dateToAtom(new Date(rows[i].dateCreated))
      rssurl = url.resolve(appurl, '/rss')
      rsstime = cutil.dateToAtom()

      res.contentType '.atom'
      res.render 'rss', {
          layout: false,
          locals: {
            albums: rows
            author: settings.appAuthor
            rssurl: rssurl
            rsstime: rsstime
          }
        }

  )

