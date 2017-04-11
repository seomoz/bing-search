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

  constructor: (@accountKey, @parallel = 10, @useGzip = true) ->

  sanitizeOptions: (options) ->
    options = _.defaults options, {
      count: Search.PAGE_SIZE
      offset: 0
    }
    options = _.omit options, 'market' if options.market not in markets

    options

  search: (options, callback) ->
    uri = "#{BING_SEARCH_ENDPOINT}/search"
    if options.endpoint?
      uri = "#{BING_SEARCH_ENDPOINT}/#{options.endpoint}"
      options = _.omit options, 'endpoint'

    requestOptions =
      uri: uri
      qs: @sanitizeOptions(options),
      headers:
        'Ocp-Apim-Subscription-Key': @accountKey
      json: true
      gzip: @useGzip

    req = request requestOptions, (err, res, body) ->
      unless err or res.statusCode is 200
        err or= new Error "Bad Bing API response #{res.statusCode}"
      return callback err if err

      callback null, body

    debug url.format req.uri

  # This allows us to execute multiple asynchronous HTTP requests for larger sets.
  parallelSearch: (responseParser, options, callback) ->
    allRequestOptions = []

    top = Search.MAX_RESULTS
    if options.top?
      top = Number options.top
      options = _.omit options, 'top'

    allRequestOptions.push _.defaults {
        count: Math.min Search.PAGE_SIZE, top - offset
        offset
    }, options for offset in [0...top] by Search.PAGE_SIZE

    async.mapLimit allRequestOptions, @parallel, _.bind(@search, this),
      (err, responses) ->
        callback err if err?

        results = []
        responses.forEach (response) ->
          results = _.union results, responseParser response
        callback null, results

  # This modifies the endpoint used for searching to retrieve params specific
  # to separate verticals (i.e. width/height for images and runtime for videos).
  verticalSearch: (vertical, responseParser, q, options, callback) ->
    [callback, options] = [options, {}] if _.compact(arguments).length is 4

    options = _.extend({}, options, {q, endpoint: "#{vertical}/search"})
    @parallelSearch responseParser, options, callback

  # This sends the vertical via the responseFilters query param for methods
  # which don't have specific verticals (i.e. web, spelling, related).
  filteredSearch: (responseFilter, responseParser, q, options, callback) ->
    [callback, options] = [options, {}] if _.compact(arguments).length is 4

    options = _.extend({}, options, {q, responseFilter})
    @parallelSearch responseParser, options, callback

  web: (query, options, callback) ->
    @filteredSearch 'webpages', _.bind(@extractWebResults, this), query, options,
      callback

  extractWebResults: (results) ->
    _.map results.webPages.value, (entry) ->
      id: entry.id
      title: entry.name
      description: entry.snippet
      displayUrl: entry.displayUrl
      url: entry.url

  images: (query, options, callback) ->
    @verticalSearch 'images', _.bind(@extractImageResults, this), query, options,
      callback

  extractImageResults: (results) ->
    # @todo size/type are different
    # https://msdn.microsoft.com/en-us/library/mt707570.aspx#image
    _.map results.value, (entry) ->
      id: entry.imageId
      title: entry.name
      url: entry.contentUrl
      sourceUrl: entry.hostPageUrl
      displayUrl: entry.hostPageDisplayUrl
      width: Number entry.width
      height: Number entry.height
      size: Number entry.contentSize
      type: entry.encodingFormat
      thumbnail:
        # @todo size/type don't exist
        url: entry.thumbnailUrl
        width: Number entry.thumbnail.width
        height: Number entry.thumbnail.height

  videos: (query, options, callback) ->
    @verticalSearch 'videos', _.bind(@extractVideoResults, this), query, options,
      callback

  extractVideoResults: (results) ->
    # @todo duration is different
    # https://msdn.microsoft.com/en-us/library/mt707570.aspx#video
    _.map results.value, (entry) ->
        id: entry.videoId
        title: entry.name
        url: entry.contentUrl
        displayUrl: entry.webSearchUrl
        runtime: entry.duration
        thumbnail:
          # @todo size/type don't exist
          url: entry.thumbnailUrl
          width: Number entry.thumbnail.width
          height: Number entry.thumbnail.height

  news: (query, options, callback) ->
    @verticalSearch 'news', _.bind(@extractNewsResults, this), query, options,
      callback

  extractNewsResults: (results) ->
    # @todo name doesn't exist
    # https://msdn.microsoft.com/en-us/library/mt707570.aspx#news
    _.map results.value, (entry) ->
      title: entry.name
      source: entry.provider
      url: entry.url
      description: entry.description
      date: new Date entry.datePublished

  spelling: (query, options, callback) ->
    @verticalSearch 'SpellingSuggestions', _.bind(@extractSpellResults, this),
      query, options, callback

  extractSpellResults: (results) ->
    @mapResults results, ({Value}) ->
      Value

  related: (query, options, callback) ->
    @verticalSearch 'RelatedSearch', _.bind(@extractRelatedResults, this),
      query, options, callback

  extractRelatedResults: (results) ->
    @mapResults results, ({Title, BingUrl}) ->
      query: Title
      url: BingUrl

  composite: (query, options, callback) ->
    [callback, options] = [options, {}] if arguments.length is 2
    options = _.defaults {}, options, {query, sources: Search.SOURCES}

    @parallelSearch 'Composite', options, (err, results) =>
      return callback err if err

      convertToSingleSource = (results, source) ->
        {d: {results: r.d.results[0][source]}} for r in results

      callback null,
        web: @extractWebResults convertToSingleSource results, 'Web'
        images: @extractImageResults convertToSingleSource results, 'Image'
        videos: @extractVideoResults convertToSingleSource results, 'Video'
        news: @extractNewsResults convertToSingleSource results, 'News'
        spelling: @extractSpellResults convertToSingleSource results,
          'SpellingSuggestions'
        related: @extractRelatedResults convertToSingleSource results,
          'RelatedSearch'

module.exports = Search
