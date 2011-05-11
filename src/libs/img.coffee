fs = require 'fs'
path = require 'path'
step = require 'step'
im = require './imagemagick'
cutil = require './util'


# Includes image utilities
module.exports = {

  # Makes a thumbnail image
  #
  # source: path to source image
  # dest: path to thumbail file
  # width: thumbail size
  # callback: err
  makeThumbnail: (source, dest, width, callback) ->

    callback = cutil.ensureCallback callback
    self = @
    sourceDir = path.dirname source
    destDir = path.dirname dest
    nosource = false

    step(

      # check if source image and destination directory exists
      () ->
        cutil.fileExists source, @parallel()
        cutil.fileExists destDir, @parallel()
        return undefined

      # create if not
      (err, sourceexists, destexists) ->
        if err then throw err

        if not sourceexists
          nosource = true
          return null

        if destexists
          return null
        else
          fs.mkdir destDir, 0755, @
          return undefined

      # check if thumbnail already exists
      (err) ->
        if err then throw err
        if nosource then return null
        cutil.fileExists dest, @
        return undefined

      # build thumbnail if not
      (err, exists) ->
        if err then throw err
        if nosource then return null
        if exists then  return null

        args = [
          source
          '-strip',
          '-thumbnail',
          width + 'x' + width,
          '-background'
          'none'
          '-gravity'
          'center'
          '-extent'
          width + 'x' + width
          '-format'
          'png'
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
  # Thumbnails are saved to the destination folder.
  #
  # sourceDir: path to source folder
  # destDir: path to destination folder
  # width: thumbnail size
  # callback: err
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
            '-background'
            'none'
            '-gravity'
            'center'
            '-extent'
            width + 'x' + width
            '-format'
            'png'
            '-path',
            destDir
            sourceDir + '/*'
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
  # 
  # source: path to source image
  # callback: err, date object
  getDate: (source, callback) ->

    callback = cutil.ensureCallback callback
    self = @
    date = null

    step(

      # check exif info
      () ->
        im.identify ['-format', '%[exif:DateTimeOriginal]', source], @
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


  # Converts exif date/time to js date/time object
  #
  # str: Exif formatted date/time string (yyyy:mm:dd hh:mm:ss) 
  dateFromExif: (str) ->
    parts = str.split " "
    d = parts[0]
    t = '00:00:00'
    if parts.length is 2 then t = parts[1]
    dp = d.split ':'
    tp = t.split ':'
    return new Date dp[0], dp[1] - 1, dp[2], tp[0], tp[1], tp[2], 0

}

