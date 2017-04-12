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
  however, impartial result sets occur at any `count > 10`. `25` is a good
  number for avoiding holes in data and duplicate results across pages.
  ###
  @PAGE_SIZE = 25

  ###
  The MAX_RESULTS variable, used for the legacy `top` pagination option, allows
  for us to return the same default `50` results as v1.0.1 of this library.
  ###
  @MAX_RESULTS = 50

  constructor: (@accountKey, @parallelLimit = 10, @useGzip = true) ->

  sanitizeOptions: (options) ->
    # Default pagination.
    options = _.defaults options,
      count: Search.PAGE_SIZE
      offset: 0

    # Validate market; send as `mkt`.
    if options.market?
      options.mkt = options.market if option.market in markets
      options = _.omit options, 'market'

    options.q = @quote options.q
    options

  quote: (str) ->
    str = str.replace '"', '\"' # Escape existing quotes.
    str.replace /^|$/g, '"'      # Quote entire phrase.

  executeSearch: (options..., callback) ->
    options = options[0] or {}

    uri = "#{BING_SEARCH_ENDPOINT}/search"
    if options.endpoint?
      uri = "#{BING_SEARCH_ENDPOINT}/#{options.endpoint}"
      options = _.omit options, 'endpoint'
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
      return callback 'Invalid HTTP response body.' if not body?

      # Parse an ID out of result URLs.
      invalidId = false
      body.value.forEach (result) ->
        matches = (result.url or result.hostPageUrl).match /&h=([^&]+)/
        if not matches?
          invalidId = true
          return
        result.id = matches[1]
      return callback 'Unable to parse an ID out of result URL.' if invalidId

      # Return search count and results.
      callback null,
        estimatedCount: body.totalEstimatedMatches
        results: body.value

    debug url.format req.uri

  parallelSearch: (options, callback) ->
    start = options.offset or 0
    top = Search.MAX_RESULTS
    if options.top?
      top = Number options.top
      options = _.omit options, 'top'

    allRequestOptions = (for offset in [start...top] by Search.PAGE_SIZE
      _.defaults {
        count: Math.min Search.PAGE_SIZE, top - offset
        offset
      }, options
    )

    async.mapLimit allRequestOptions, @parallelLimit,
      _.bind(@executeSearch, this), (err, responses) ->
        return callback err if err

        data =
          estimatedCount: _.last(responses).estimatedCount
          results: []

        # Avoid duplicates by checking result IDs.
        existingIds = []
        responses.forEach (response) ->
          response.results.forEach (result) ->
            unless result.id in existingIds
              data.results.push result
              existingIds.push result.id

        callback null, data

  counts: (query, options..., callback) ->
    sources = []

    sources.push
      key: 'web'
      method: _.bind @rawWeb, this
    sources.push
      key: 'image'
      method: _.bind @rawImages, this
    sources.push
      key: 'video'
      method: _.bind @rawVideos, this
    sources.push
      key: 'news'
      method: _.bind @rawNews, this

    executeSearchForCounts = (source, callback) ->
      ###
      We only need to one result (zero is impossible) from most verticals. With
      a web search, however, the `totalEstimatedMatches` needs to be checked
      from a higher page for accurate data.
      
      The 1,000 value comes from empirical data. It seems that after 600
      results, the accuracy gets quite consistent and accurate. I picked 1,000
      just to be in the clear. It also doesn't matter if there are fewer than
      1,000 results.
      ###
      pagination = {offset: 0, top: 1}
      if source.key is 'web'
        _.each pagination, (value, key) ->
          pagination[key] += 1000

      source.method query, _.defaults(pagination, options), callback

    async.mapLimit sources, @parallelLimit, executeSearchForCounts,
      (err, responses) ->
        return callback err if err

        data = {}
        data[source.key] = 0 for source in sources

        responses.forEach (response, i) ->
          data[sources[i].key] = response.estimatedCount

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

  extractWebResults: ({results} = []) ->
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

  extractImageResults: ({results} = []) ->
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

  extractVideoResults: ({results} = []) ->
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

  extractNewsResults: ({results} = []) ->
    for result in results
      id: result.id
      title: result.name
      source: result.provider
      url: result.url
      description: result.description
      date: new Date result.datePublished

module.exports = Search
