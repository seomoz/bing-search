_ = require 'underscore'
async = require 'async'
debug = require('debug') 'bing-search'
request = require 'request'
url = require 'url'

markets = require './markets'

BING_SEARCH_ENDPOINT = 'https://api.cognitive.microsoft.com/bing/v5.0'

class Search
  # The PAGE_SIZE variable is used for `count` on most API requests. The
  # documentation states that the maximum results is API specific; but, all of
  # the API references just state that "the actual number delivered may be
  # less than requested." From what I've seen, searches typically return ~30
  # results; however, impartial result sets occur at any `count > 10`. `25` is
  # a good number for avoiding holes in data and duplicate results across pages.
  @PAGE_SIZE = 25

  # The MAX_RESULTS variable, used for the legacy `top` pagination option,
  # allows for us to return the same default `50` results as v1.0.1 of this
  # library.
  @MAX_RESULTS = 50

  constructor: (@accountKey, @parallelLimit = 10, @useGzip = true) ->

  _sanitizeOptions: (options) ->
    # Default pagination.
    options = _.defaults options, {
      count: Search.PAGE_SIZE
      offset: 0
    }

    # Validate market; send as `mkt`.
    if options.market?
      options.mkt = options.market if option.market in markets
      options = _.omit options, 'market'

    options.q = @_quote options.q
    options

  _quote: (str) ->
    str = str.replace '"', '\"' # Escape existing quotes.
    str.replace /^|$/g, '"'      # Quote entire phrase.

  _executeSearch: (options, callback) ->
    [callback, options] = [options, {}] if _.compact(arguments).length is 1

    uri = "#{BING_SEARCH_ENDPOINT}/search"
    if options.endpoint?
      uri = "#{BING_SEARCH_ENDPOINT}/#{options.endpoint}"
      options = _.omit options, 'endpoint'
    qs = @_sanitizeOptions(options)

    req = request {
      uri, qs
      headers:
        'Ocp-Apim-Subscription-Key': @accountKey
      json: true
      gzip: @useGzip
    }, (err, res, body) =>
      unless err or res.statusCode is 200
        err or= new Error "Bad Bing API response #{res.statusCode}"
      return callback err if err

      # Filtered searches' data lives within the webPages property.
      body = body.webPages if body._type is 'SearchResponse'
      return callback 'Invalid HTTP response body.' if not body?

      # Parse an ID out of result URLs.
      invalidId = false
      body.value.forEach (result) ->
        matches = (result.url || result.hostPageUrl).match /&h=([^&]+)/
        if not matches?
          invalidId = true
          return
        result.id = matches[1]
      return callback 'Unable to parse an ID out of result URL.' if invalidId

      # Return search count and results.
      callback null, {
        count: body.totalEstimatedMatches,
        results: body.value
      }

    debug url.format req.uri

  _parallelSearch: (options, callback) ->
    allRequestOptions = []

    top = Search.MAX_RESULTS
    if options.top?
      top = Number options.top
      options = _.omit options, 'top'

    allRequestOptions.push _.defaults {
      count: Math.min Search.PAGE_SIZE, top - offset
      offset
    }, options for offset in [(options.offset || 0)...top] by Search.PAGE_SIZE

    async.mapLimit allRequestOptions, @parallelLimit, _.bind(@_executeSearch, this),
      (err, responses) ->
        callback err if err?

        data = {
          count: 0
          results: []
        }

        # Avoid duplicates by checking result IDs.
        existingIds = []
        responses.forEach (response) ->
          data.count = response.count if response.count?
          response.results.forEach (result) ->
            unless result.id in existingIds
              data.results.push result
              existingIds.push result.id

        callback null, data

  counts: (query, options, callback) ->
    [callback, options] = [options, {}] if _.compact(arguments).length is 2

    sources = ['web', 'images', 'videos', 'news']
    methods = {
      web: _.bind @_rawWeb, this
      images: _.bind @_rawImages, this
      videos: _.bind @_rawVideos, this
      news: _.bind @_rawNews, this
    }

    executeSearch = (source, callback) =>
      # We only need to one result (zero is impossible) from most verticals.
      # With a web search, however, the `totalEstimatedMatches` needs to be
      # checked from a higher page for accurate data.
      #
      # The 1,000 value comes from empirical data. It seems that after 600
      # results, the accuracy gets quite consistent and accurate. I picked 1,000
      # just to be in the clear. It also doesn't matter if there are fewer than
      # 1,000 results.
      pagination = {offset: 0, top: 1}
      if source is 'web'
        _.each pagination, (value, key) ->
          pagination[key] += 1000

      methods[source] query, (_.defaults pagination, options), callback

    async.mapLimit sources, @parallelLimit, executeSearch,
      (err, responses) ->
        callback err if err?

        data = {}
        data[source] = 0 for source in sources

        responses.forEach (response, i) ->
          data[sources[i]] = response.count

        callback null, data

  # This modifies the endpoint used for searching to retrieve params specific
  # to separate verticals (i.e. width/height for images and runtime for videos).
  _verticalSearch: (vertical, q, options, callback) ->
    options = _.extend({}, options, {q, endpoint: "#{vertical}/search"})
    @_parallelSearch options, callback

  # This sends the vertical via the responseFilters query param for methods
  # which don't have specific verticals (i.e. web, spelling, related).
  _filteredSearch: (responseFilter, q, options, callback) ->
    options = _.extend({}, options, {q, responseFilter})
    @_parallelSearch options, callback

  _rawWeb: (query, options, callback) ->
    @_filteredSearch 'webpages', query, options, callback

  web: (query, options, callback) ->
    [callback, options] = [options, {}] if _.compact(arguments).length is 2

    @_rawWeb query, options, (err, data) =>
      callback err if err?
      callback null, @_extractWebResults data

  _extractWebResults: (data) ->
    _.map data.results, (result) ->
      id: result.id
      title: result.name
      description: result.snippet
      url: result.url
      displayUrl: result.displayUrl

  _rawImages: (query, options, callback) ->
    @_verticalSearch 'images', query, options, callback

  images: (query, options, callback) ->
    [callback, options] = [options, {}] if _.compact(arguments).length is 2

    @_rawImages query, options, (err, data) =>
      callback err if err?
      callback null, @_extractImageResults data

  _extractImageResults: (data) ->
    _.map data.results, (result) ->
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
        width: Number result.thumbnail.width
        height: Number result.thumbnail.height

  _rawVideos: (query, options, callback) ->
    @_verticalSearch 'videos', query, options, callback

  videos: (query, options, callback) ->
    [callback, options] = [options, {}] if _.compact(arguments).length is 2

    @_rawVideos query, options, (err, data) =>
      callback err if err?
      callback null, @_extractVideoResults data

  _extractVideoResults: (data) ->
    _.map data.results, (result) ->
      id: result.id
      title: result.name
      url: result.contentUrl
      displayUrl: result.webSearchUrl
      runtime: result.duration
      thumbnail:
        url: result.thumbnailUrl
        width: Number result.thumbnail.width
        height: Number result.thumbnail.height

  _rawNews: (query, options, callback) ->
    @_verticalSearch 'news', query, options, callback

  news: (query, options, callback) ->
    [callback, options] = [options, {}] if _.compact(arguments).length is 2

    @_rawNews query, options, (err, data) =>
      callback err if err?
      callback null, @_extractNewsResults data

  _extractNewsResults: (data) ->
    _.map data.results, (result) ->
      id: result.id
      title: result.name
      source: result.provider
      url: result.url
      description: result.description
      date: new Date result.datePublished

module.exports = Search
