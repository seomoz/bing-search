_ = require 'underscore'
async = require 'async'
debug = require('debug') 'bing-search'
request = require 'request'
url = require 'url'

markets = require './markets'

BING_SEARCH_ENDPOINT = 'https://api.cognitive.microsoft.com/bing/v5.0'

class Search
  ###
  The PAGE_SIZE variable is used for `count` on most API requests. The
  documentation states that the maximum results is API specific; but, all of
  the API references just state that "the actual number delivered may be less
  than requested." From what I've seen, searches typically return ~30  results;
  however, incomplete result sets occur at any `count > 10`. `25` is a good
  number for avoiding holes in data and duplicate results across pages.
  ###
  @PAGE_SIZE = 25

  ###
  The MAX_RESULTS variable, used for the legacy `top` pagination option, allows
  for us to return the same default `50` results as v1.0.1 of this library.
  ###
  @MAX_RESULTS = 50

  ###
  We only need one result (zero is impossible) from most verticals. With a web
  search, however, the `totalEstimatedMatches` needs to be checked from a higher
  page for accurate data.

  The 1,000 value comes from empirical data. It seems that after 600
  results, the accuracy gets quite consistent and accurate. I picked 1,000
  just to be in the clear. It also doesn't matter if there are fewer than
  1,000 results.
  ###
  @COUNT_ACCURACY_OFFSET = 1000

  constructor: (@accountKey, @parallelLimit = 10, @useGzip = true) ->

  sanitizeOptions: (options) ->
    # Default pagination.
    options = _.defaults options,
      count: Search.PAGE_SIZE
      offset: 0

    # Validate market; send as `mkt`.
    if options.market?
      options.mkt = options.market if option.market in markets
      delete options.market

    options.q = @sanitizeQuery options.q
    options

  # Normalize whitespace and then quote phrases.
  sanitizeQuery: (query) ->
    query = query.replace /\s{2,}|[\r\n]+/g, ' '
    unless '"' in query then '"' + query + '"' else query

  executeSearch: (options..., callback) ->
    options = options[0] or {}

    uri = "#{BING_SEARCH_ENDPOINT}/" +
      (if options.endpoint then options.endpoint else 'search')

    delete options.endpoint
    qs = @sanitizeOptions options

    req = request {
      uri, qs
      headers:
        'Ocp-Apim-Subscription-Key': @accountKey
      json: true
      gzip: @useGzip
    }, (err, res, body) ->
      unless err or res.statusCode is 200
        err or= new Error "Bad Bing API response #{res.statusCode}"
      return callback err if err

      # Filtered searches' data lives within the webPages property.
      body = body.webPages if body._type is 'SearchResponse'

      # Empty responses can cause errors, and should be returned right away.
      unless body
        return callback null,
          estimatedCount: 0
          results: []

      # Parse an ID out of result URLs for compatibility and duplicate checks.
      invalidId = false
      body.value.forEach (result) ->
        matches = (result.url or result.hostPageUrl).match /&h=([^&]+)/
        if matches
          result.id = matches[1]
        else
          invalidId = true
      if invalidId
        return callback _.extend new Error('Unable to parse an ID out of result URL.'),
          url: result.url or result.hostPageUrl

      callback null,
        estimatedCount: body.totalEstimatedMatches
        results: body.value

    debug url.format req.uri

  parallelSearch: (options, callback) ->
    start = options.offset or 0
    top = Search.MAX_RESULTS
    if options.top?
      top = Number options.top
      delete options.top

    allRequestOptions = (for offset in [start...top] by Search.PAGE_SIZE
      _.defaults {
        count: Math.min Search.PAGE_SIZE, top - offset
        offset
      }, options
    )

    async.mapLimit allRequestOptions, @parallelLimit,
      _.bind(@executeSearch, this), (err, responses) ->
        return callback err if err

        ###
        This `estimatedCount` is Bing's approximation of the total number of
        results for a query. This is used for the `counts()` method and does
        not relate to `results.length` in any way. We chose the last response's
        `estimatedCount` since this value gets more accurate the higher the
        search's `offset`.
        ###
        data =
          estimatedCount: _.last(responses).estimatedCount
          results: []

        # Avoid duplicates by checking result IDs.
        existingIds = {}
        responses.forEach (response) ->
          response.results.forEach (result) ->
            unless result.id of existingIds
              data.results.push result
              existingIds[result.id] = true

        callback null, data

  counts: (query, options..., callback) ->
    sources = [
      key: 'web'
      method: _.bind @rawWeb, this
    ,
      key: 'image'
      method: _.bind @rawImages, this
    ,
      key: 'video'
      method: _.bind @rawVideos, this
    ,
      key: 'news'
      method: _.bind @rawNews, this
    ]

    executeSearchForCounts = (source, callback) ->
      pagination = {offset: 0, top: 1}
      if source.key is 'web'
        pagination.offset += Search.COUNT_ACCURACY_OFFSET
        pagination.top += Search.COUNT_ACCURACY_OFFSET

      source.method query, _.defaults(pagination, options), callback

    async.mapLimit sources, @parallelLimit, executeSearchForCounts,
      (err, responses) ->
        return callback err if err

        data = {}
        responses.forEach (response, i) ->
          data[sources[i].key] = response.estimatedCount or 0
        callback null, data

  # This modifies the endpoint used for searching to retrieve params specific
  # to separate verticals (i.e. width/height for images and runtime for videos).
  verticalSearch: (vertical, q, options, callback) ->
    options = _.extend {}, options, {q, endpoint: "#{vertical}/search"}
    @parallelSearch options, callback

  # This sends the vertical via the responseFilters query param for methods
  # which don't have specific verticals (i.e. web, spelling, related).
  filteredSearch: (responseFilter, q, options, callback) ->
    options = _.extend {}, options, {q, responseFilter}
    @parallelSearch options, callback

  rawWeb: (query, options, callback) ->
    @filteredSearch 'webpages', query, options, callback

  web: (query, options..., callback) ->
    options = options[0] or {}
    @rawWeb query, options, (err, data) =>
      callback err, (@extractWebResults data unless err)

  extractWebResults: ({results} = {}) ->
    for result in results
      id: result.id
      title: result.name
      description: result.snippet
      url: result.url
      displayUrl: result.displayUrl

  rawImages: (query, options, callback) ->
    @verticalSearch 'images', query, options, callback

  images: (query, options..., callback) ->
    options = options[0] or {}
    @rawImages query, options, (err, data) =>
      callback err, (@extractImageResults data unless err)

  extractImageResults: ({results} = {}) ->
    for result in results
      id: result.id
      title: result.name
      url: result.contentUrl
      sourceUrl: result.hostPageUrl
      displayUrl: result.hostPageDisplayUrl
      width: Number result.width
      height: Number result.height
      size: result.contentSize
      type: result.encodingFormat
      thumbnail:
        url: result.thumbnailUrl
        width: result.thumbnail.width
        height: result.thumbnail.height

  rawVideos: (query, options, callback) ->
    @verticalSearch 'videos', query, options, callback

  videos: (query, options..., callback) ->
    options = options[0] or {}
    @rawVideos query, options, (err, data) =>
      callback err, (@extractVideoResults data unless err)

  extractVideoResults: ({results} = {}) ->
    for result in results
      id: result.id
      title: result.name
      url: result.contentUrl
      displayUrl: result.webSearchUrl
      runtime: result.duration
      thumbnail:
        url: result.thumbnailUrl
        width: result.thumbnail.width
        height: result.thumbnail.height

  rawNews: (query, options, callback) ->
    @verticalSearch 'news', query, options, callback

  news: (query, options..., callback) ->
    options = options[0] or {}
    @rawNews query, options, (err, data) =>
      callback err, (@extractNewsResults data unless err)

  extractNewsResults: ({results} = {}) ->
    for result in results
      id: result.id
      title: result.name
      source: result.provider
      url: result.url
      description: result.description
      date: new Date result.datePublished

module.exports = Search
