path = require 'path'


# Utility functions
class Utility


  # Ensures that the callback is a function
  # 
  # callback: the callback to check
  ensureCallback: (callback) ->
    def = () ->
    callback or= def


  # path.exists with err argument
  #
  # file: path to a file
  # callback: err, exists (true or false)
  fileExists: (file, callback) ->
    callback = @ensureCallback callback
    path.exists file, (exists) ->
      callback null, exists


  # Returns an arrays of objects { text, selected, islink, url } representing pages
  #
  # uri: base uri
  # pages: page count
  makePagination: (uri, pages) ->
    if pages <= 1 then return null

    parts = url.parse uri, true
    if not parts.query?
      parts.query = { page: '1' }
    if not parts.query.page?
      parts.query.page = '1'
    page = parts.query.page
    pagination = []

    for i in [1...(1 + pages)]
      opage = {}
      opage.text = String(i)
      opage.selected = if String(i) is page then true else false
      opage.islink = !opage.selected
      parts.query.page = String(i)
      opage.url = url.format parts
      pagination.push opage

    return pagination


module.exports = new Utility

