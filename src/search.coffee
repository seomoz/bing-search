_ = require 'underscore'
async = require 'async'
debug = require('debug') 'bing-search'
request = require 'request'
url = require 'url'

markets = require './markets'

BING_SEARCH_ENDPOINT = 'https://api.cognitive.microsoft.com/bing/v5.0'

class Search
  @SOURCES = ['WebPages', 'Images', 'Videos', 'News', 'SpellSuggestions', 'RelatedSearches']
  @PAGE_SIZE = 150

  constructor: (@accountKey, @parallel = 10, @useGzip = true) ->

  requestOptions: (options) ->
    reqOptions =
      q: @quoted options.query
      count: Search.PAGE_SIZE
      offset: 0
    reqOptions.mkt = options.market if options.market in markets

    reqOptions

  # Given a list of strings, generates a string wrapped in single quotes with
  # the list entries separated by a `+`.
  quoted: (values) ->
    values = [values] unless _.isArray values
    values = (v.replace "'", "''" for v in values)
    "'#{values.join '+'}'"

  # Generates a sequence of numbers no larger than the page size which the sum
  # of the list equal to numResults.
  generateTops: (numResults, pageSize = Search.PAGE_SIZE) ->
    tops = [numResults % pageSize] if numResults % pageSize isnt 0
    tops or= []
    (pageSize for i in [0...Math.floor(numResults / pageSize)]).concat tops

  # Generate a sequence of offsets as a multiple of page size starting at
  # skipStart and ending before skipStart + numResults.
  generateSkips: (numResults, skipStart) ->
    skips = [skipStart]
    for count in @generateTops(numResults)[...-1]
      skips.push skips[skips.length - 1] + count
    skips

  parallelSearch: (vertical, options, callback) ->
    opts = _.extend {}, {top: Search.PAGE_SIZE, skip: 0}, options

    # Generate search options for each of the search requests.
    pairs = _.zip @generateTops(opts.top), @generateSkips(opts.top, opts.skip)
    requestOptions = _.map pairs, ([top, skip]) ->
      _.defaults {top, skip}, options

    search = (options, callback) =>
      @search vertical, options, callback

    async.mapLimit requestOptions, @parallel, search, callback

  search: (vertical, options, callback) ->
    requestOptions =
      uri: "#{BING_SEARCH_ENDPOINT}/#{vertical}/search"
      qs: @requestOptions(options),
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

  counts: (query, callback) ->
    getCounts = (options, callback) =>
      options = _.extend {}, options, {query, sources: Search.SOURCES}
      @search 'Composite', options, (err, result) =>
        return callback err if err
        callback null, @extractCounts result

    # Two requests are needed. The first request is to get an accurate
    # web results count and the second request is to get an accurate count
    # for the rest of the verticals.
    #
    # The 1,000 value comes from empirical data. It seems that after 600
    # results, the accuracy gets quite consistent and accurate. I picked 1,000
    # just to be in the clear. It also doesn't matter if there are fewer than
    # 1,000 results.
    async.map [{skip: 1000}, {}], getCounts, (err, results) ->
      return callback err if err
      callback null, _.extend results[1], _.pick(results[0], 'web')

  extractCounts: (result) ->
    keyRe = /(\w+)Total$/

    _.chain(result?.d?.results or [])
      .first()
      .pairs()
      .filter ([key, value]) ->
        # Eg. WebTotal, ImageTotal, ...
        keyRe.test key
      .map ([key, value]) ->
        # Eg. WebTotal => web
        key = keyRe.exec(key)[1].toLowerCase()
        value = Number value

        switch key
          when 'spellingsuggestions' then ['spelling', value]
          else [key, value]
      .object()
      .value()

  verticalSearch: (vertical, verticalResultParser, query, options, callback) ->
    [callback, options] = [options, {}] if _.compact(arguments).length is 4

    @parallelSearch vertical, _.extend({}, options, {query}), (err, result) ->
      return callback err if err
      callback null, verticalResultParser result

  mapResults: (results, fn) ->
    _.chain(results)
      .pluck('value')
      .flatten()
      .map fn
      .value()

  web: (query, options, callback) ->
    @verticalSearch 'Web', _.bind(@extractWebResults, this), query, options,
      callback

  extractWebResults: (results) ->
    @mapResults results, ({ID, Title, Description, DisplayUrl, Url}) ->
      id: ID
      title: Title
      description: Description
      displayUrl: DisplayUrl
      url: Url

  images: (query, options, callback) ->
    @verticalSearch 'Images', _.bind(@extractImageResults, this), query, options,
      callback

  extractImageResults: (results) ->
    # @todo size/type are different
    # https://msdn.microsoft.com/en-us/library/mt707570.aspx#image
    @mapResults results, (entry) =>
      id: entry.imageId
      title: entry.name
      url: entry.contentUrl
      sourceUrl: entry.hostPageUrl
      displayUrl: entry.hostPageDisplayUrl
      width: Number entry.width
      height: Number entry.height
      size: Number entry.contentSize
      type: entry.encodingFormat
      thumbnail: @extractThumbnail entry

  extractThumbnail: (entry) ->
    # @todo size/type don't exist
    # https://msdn.microsoft.com/en-us/library/mt707570.aspx#image
    url: entry.thumbnailUrl
    width: Number entry.thumbnail.width
    height: Number entry.thumbnail.height

  videos: (query, options, callback) ->
    @verticalSearch 'Videos', _.bind(@extractVideoResults, this), query, options,
      callback

  extractVideoResults: (results) ->
    # @todo duration is different
    # https://msdn.microsoft.com/en-us/library/mt707570.aspx#video
    @mapResults results,
      (entry) =>
        id: entry.videoId
        title: entry.name
        url: entry.contentUrl
        displayUrl: entry.webSearchUrl
        runtime: entry.duration
        thumbnail: @extractThumbnail entry

  news: (query, options, callback) ->
    @verticalSearch 'News', _.bind(@extractNewsResults, this), query, options,
      callback

  extractNewsResults: (results) ->
    @mapResults results, (entry) ->
      id: entry.ID
      title: entry.Title
      source: entry.Source
      url: entry.Url
      description: entry.Description
      date: new Date entry.Date

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
