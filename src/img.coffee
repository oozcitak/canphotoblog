fs = require 'fs'
path = require 'path'
im = require './libs/imagemagick'
cutil = require './util'


# Includes image utilities
class Image


  # Makes a thumbnail image
  makeThumbnail: (source, dest, width, callback) ->

    callback = cutil.ensureCallback callback
    self = @
    sourceDir = path.dirname source
    destDir = path.dirname dest

    step(

      # check if directory exists
      () ->
        cutil.fileExists destDir, @
        return undefined

      # create if not
      (err, exists) ->
        if err then throw err
        if not exists
          fs.mkdir destDir, 0755, @
          return undefined
        else
          return null

      # check if thumbnail already exists
      (err) ->
        if err then throw err
        cutil.fileExists dest, @
        return undefined

      # build thumbnail if not
      (err, exists) ->
        if err then throw err
        if exists
          return null
        else
          args = [
              source,
              '-strip',
              '-thumbnail',
              width + 'x' + width,
              dest
            ]
          im.convert args, @
          return undefined

      # execute callback
      (err) ->
        if err then throw err
        callback err
    )


  # Makes thumbnail images for all images in the source folder.
  # Thumbnails are saved to the dest folder.
  makeAllThumbnails: (sourceDir, destDir, width, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # check if directory exists
      () ->
        cutil.fileExists destDir, @
        return undefined

      # create if not
      (err, exists) ->
        if err then throw err
        if not exists
          fs.mkdir destDir, 0755, @
          return undefined
        else
          return null

      # build thumbnails
      (err, exists) ->
        if err then throw err
        args = [
            '-strip',
            '-thumbnail',
            width + 'x' + width,
            '-background',
            'white',
            '-gravity',
            'center',
            '-extent',
            width + 'x' + width,
            '-path',
            destDir
            path.join sourceDir, '*.jpg'
          ]
        im.mogrify args, @
        return undefined

      # execute callback
      (err) ->
        if err then throw err
        callback err
    )


  # Returns a Date object representing the date the source image
  # was taken. If Exif date field does not exist falls back to the
  # date the image was last modified.
  getDate: (source, callback) ->

    callback = cutil.ensureCallback callback
    self = @
    date = null

    step(

      # check exif info
      () ->
        im.identify ['-format', '%[exif:DateTimeOriginal'], source, @
        return undefined

      # fall back to FS
      (err, exifDate) ->
        if err then throw err

        if exifDate
          date = self.dateFromExif exifDate
          return null

        fs.stat source, @
        return undefined

      # execute callback
      (err, stats) ->
        if err then throw err
        if stats then date = new Date(stats.mtime)

        callback err, date
    )


  # Converts exif date/time (yyyy:mm:dd hh:mm:ss) to js date/time
  dateFromExif: (str) ->
    parts = str.split " "
    d = parts[0]
    t = '00:00:00'
    if parts.length is 2 then t = parts[1]
    dp = d.split ':'
    tp = t.split ':'
    return new Date dp[0], dp[1], dp[2], tp[0], tp[1], tp[2], 0


module.exports = new Image

