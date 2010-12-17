path = require 'path'
util = require 'util'
url = require 'url'
crypto = require 'crypto'


# Utility functions
module.exports = {

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


  # Joins object and returns the resulting object
  #
  # a, b: objects to join
  joinObjects: (a, b) ->
    c = a
    for item in b
      c[item.name] = item.value
    return c


  # Hashes the given data and returns the digest
  #
  # data: the data to hash
  # algo: hashing algorithm, defaults to 'sha1'
  # enc: encoding, defaults to 'hex'
  hash: (data, algo, enc) ->
    algo or= 'sha1'
    enc or= 'hex'
    return crypto.createHash(algo).update(data).digest(enc)


  # Hashes the given string with a random salt.
  # Returns the salt hash prepended to the hashed string.
  #
  # input: the string to hash
  # salt: the hash salt. null to generate a random salt
  makeHash: (input, salt) ->
    inputHash = @hash input
    if not salt or salt.length isnt 32
      salt = @hash Math.random(), 'md5'
    return salt + @hash(inputHash + salt)


  # Determines whether the input string matches the hashed string.
  # Returns true if the strings match; otherwise false.
  #
  # input: the string to check
  # hashed: the hashed string to check against
  checkHash: (input, hashed) ->
    salt = hashed.substr 0, 32
    inputHash = @makeHash input, salt
    return hashed is inputHash


  # Converts a Date object to sqlite date string formatted as
  # YYYY-MM-DD HH:MM:SS.
  #
  # date: a date object, default to current date/time
  # time: true to include time, defaults to true
  dateToSQLite: (date, time) ->
    if not date then date = new Date()
    if time isnt false then time = true

    y = date.getFullYear()
    m = date.getMonth() + 1
    d = date.getDate()
    hh = date.getHours()
    mm = date.getMinutes()
    ss = date.getSeconds()

    if m < 10 then m = '0' + m
    if d < 10 then d = '0' + d
    if hh < 10 then hh = '0' + hh
    if mm < 10 then mm = '0' + mm
    if ss < 10 then ss = '0' + ss

    if time
      return y + '-' + m + '-' + d + ' ' + hh + ':' + mm + ':' + ss
    else
      return y + '-' + m + '-' + d


  # Function to return the pagination. Converted from original
  # php version at
  # http://www.strangerstudios.com/sandbox/pagination/diggstyle.php
  #
  # targeturl: the URL of the page
  # totalpages: the total number of pages
  getPagination: (targeturl, totalpages) ->

    if totalpages <= 1 then return []
    lastpage = totalpages
    lpm1 = lastpage - 1

    adjacents = 1
  
    # parse url
    urlparts = url.parse targeturl, true
    pathname = urlparts.pathname
    query = urlparts.query or { page: '1' }
    if not query.page? then query.page = '1'
    page = parseInt(query.page)
    prev = page - 1
    next = page + 1

    pagination = []

    # previous button
    if page > 1
      pagination.push getPaginationLinkPart targeturl, prev, '&laquo;', 'button'
    else
      pagination.push getPaginationTextPart '&laquo;', false, 'button'

    # pages
    if (lastpage < 7 + (adjacents * 2))  # not enough pages to bother breaking it up
      for counter in [1...(lastpage + 1)]
        if counter is page
          pagination.push getPaginationTextPart counter, true
        else
          pagination.push getPaginationLinkPart targeturl, counter

    else if (lastpage >= 7 + (adjacents * 2))  # enough pages to hide some

      # close to beginning; only hide later pages
      if (page < 1 + (adjacents * 3))
        for counter in [1...(4 + (adjacents * 2))]
          if counter is page
            pagination.push getPaginationTextPart counter, true
          else
            pagination.push getPaginationLinkPart targeturl, counter
        pagination.push getPaginationTextPart '...', false, 'ellipsis'
        pagination.push getPaginationLinkPart targeturl, lpm1
        pagination.push getPaginationLinkPart targeturl, lastpage

      # in middle; hide some front and some back
      else if (lastpage - (adjacents * 2) > page and page > (adjacents * 2))
        pagination.push getPaginationLinkPart targeturl, 1
        pagination.push getPaginationLinkPart targeturl, 2
        pagination.push getPaginationTextPart '...', false, 'ellipsis'
        for counter in [(page - adjacents)...(page + adjacents + 1)]
          if counter is page
            pagination.push getPaginationTextPart counter, true
          else
            pagination.push getPaginationLinkPart targeturl, counter
        pagination.push getPaginationTextPart '...', false, 'ellipsis'
        pagination.push getPaginationLinkPart targeturl, lpm1
        pagination.push getPaginationLinkPart targeturl, lastpage

      # close to end; only hide early pages
      else
        pagination.push getPaginationLinkPart targeturl, 1
        pagination.push getPaginationLinkPart targeturl, 2
        pagination.push getPaginationTextPart '...', false, 'ellipsis'
        for counter in [(lastpage - (1 + (adjacents * 3)))...(1 + lastpage)]
          if counter is page
            pagination.push getPaginationTextPart counter, true
          else
            pagination.push getPaginationLinkPart targeturl, counter
    
    # next button
    if page < counter - 1
      pagination.push getPaginationLinkPart targeturl, next, '&raquo;', 'button'
    else
      pagination.push getPaginationTextPart '&raquo;', false, 'button'
  
    return pagination

}


# Returns a text part for use in pagination
#
# text: text of the part
# current: true if this is the current page, optional default to false
getPaginationTextPart = (text, current, classname) ->
  if not current? then current = false
  classname or= ''
  return { text: String(text), islink : false, current: current, classname: classname }


# Returns a link part for use in pagination
#
# targeturl: the url of the page
# page: current page number
# text: text of the part, optional defaults to page
# classname: name of the css class for this element, optional
getPaginationLinkPart = (targeturl, page, text, classname) ->
  page = String(page)
  text or= page
  classname or= ''
  urlparts = url.parse targeturl, true
  urlparts.query or= { page: '' }
  urlparts.query.page = page
  urlparts = { pathname: urlparts.pathname, query: urlparts.query }
  targeturl = url.format urlparts
  return { text: text, islink : true, url: targeturl, current: false, classname: classname }

