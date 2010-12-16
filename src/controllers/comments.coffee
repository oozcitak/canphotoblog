util = require 'util'
step = require 'step'

app = module.parent.exports
db = app.set 'db'
akismet = app.set 'akismet'
settings = app.set 'settings'

Comments = require '../models/comments'
comments = new Comments db, akismet


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


# GET /comments
app.get '/comments', (req, res) ->

  page = req.query.page || 1

  step(

    # get commented albums
    () ->
      comments.getCommentedPictures page, settings.picturesPerPage, @parallel()
      comments.countCommentedPictures @parallel()
      return undefined

    # render page
    (err, comments, count) ->
      if err then throw err

      app.helpers { pageCount: Math.ceil(count / settings.picturesPerPage) }

      res.render 'comments', {
          locals: {
            comments: comments
          }
        }

  )


