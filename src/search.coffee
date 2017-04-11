_ = require 'underscore'
async = require 'async'
debug = require('debug') 'bing-search'
request = require 'request'
url = require 'url'

markets = require './markets'

BING_SEARCH_ENDPOINT = 'https://api.cognitive.microsoft.com/bing/v5.0'

class Search
  # The PAGE_SIZE variable, used for `count`, was chosen with empirical data.
  # The documentation states that the maximum results is API specific; but, all
  # of the API references just state that "the actual number delivered may be
  # less than requested." From what I've seen, searches typically return ~30
  # results. If anything, I'd be lowering this number to avoid unknown gaps.
  @PAGE_SIZE = 25

  # The MAX_RESULTS variable, used for the legacy `top` pagination option,
  # allows for us to return the same default 50 results as v1.0.1 of this lib.
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

    options

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

      callback null, @_parseBody body

    debug url.format req.uri

  _parseBody: (body) ->
    # Filtered searches' data lives within the webPages property.
    body = body.webPages if body._type is 'SearchResponse'

    {
      count: body.totalEstimatedMatches,
      results: body.value
    }

  _parallelSearch: (options, callback) ->
    allRequestOptions = []

    top = Search.MAX_RESULTS
    if options.top?
      top = Number options.top
      options = _.omit options, 'top'

    allRequestOptions.push _.defaults {
      count: Math.min Search.PAGE_SIZE, top - offset
      offset
    }, options for offset in [0...top] by Search.PAGE_SIZE

    async.mapLimit allRequestOptions, @parallelLimit, _.bind(@_executeSearch, this),
      (err, responses) ->
        callback err if err?

        data = {
          count: 0
          results: []
        }

        responses.forEach (response) ->
          data.count = response.count
          data.results = _.union data.results, response.results

        callback null, data

  count: (query, options, callback) ->
    [callback, options] = [options, {}] if _.compact(arguments).length is 2

    sources = ['web', 'images', 'videos', 'news']
    methods = {
      web: _.bind @_rawWeb, this
      images: _.bind @_rawImages, this
      videos: _.bind @_rawVideos, this
      news: _.bind @_rawNews, this
    }

    _.extend options, {top: 1}
    search = (source, callback) =>
      methods[source] query, options, callback

    async.mapLimit sources, @parallelLimit, search,
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
    # @todo no ID equivalent
    _.map data.results, (result) ->
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
    # @todo no ID equivalent
    # @todo size/type are different
    _.map data.results, (result) ->
      title: result.name
      url: result.contentUrl
      sourceUrl: result.hostPageUrl
      displayUrl: result.hostPageDisplayUrl
      width: Number result.width
      height: Number result.height
      size: result.contentSize
      type: result.encodingFormat
      thumbnail:
        # @todo size/type don't exist
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
    # @todo no ID equivalent
    # @todo duration is different
    _.map data.results, (result) ->
      title: result.name
      url: result.contentUrl
      displayUrl: result.webSearchUrl
      runtime: result.duration
      thumbnail:
        # @todo size/type don't exist
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
    # @todo no ID equivalent
    # @todo name doesn't exist
    _.map data.results, (result) ->
      title: result.name
      source: result.provider
      url: result.url
      description: result.description
      date: new Date result.datePublished

module.exports = Search
