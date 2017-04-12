Search = require '../src/search'
nock = require 'nock'
should = require 'should'
util = require 'util'
fs = require 'fs'

ACCOUNT_KEY = 'test'
RECORD = false
RECORDED_FILE = 'test/bing_nock.json'

describe 'search', ->
  search = null

  beforeEach ->
    search = new Search ACCOUNT_KEY, 1, false

  before ->
    if RECORD
      nock.recorder.rec output_objects: true
    else
      nock.load RECORDED_FILE

  after ->
    if RECORD
      out = JSON.stringify nock.recorder.play(), null, 2
      fs.writeFileSync RECORDED_FILE, out

  describe 'quote', ->
    it 'should put a phrase in quotes', (done) ->
      search._quote('Moz').should.eql '"Moz"'
      done()
    it 'should escape quotes within phrases', (done) ->
      search._quote('"Moz"').should.eql '"\"Moz\""'
      done()

  describe 'counts', ->
    it 'should return counts for all verticals', (done) ->
      search.counts 'Moz', (err, results) ->
        should.not.exist err
        results.should.eql
          web: 325
          images: 776
          videos: 145
          news: 112000
        done()

  describe 'web', ->
    it 'should return results', (done) ->
      search.web 'Moz', (err, results) ->
        should.not.exist err
        results.length.should.eql 47
        results[0].should.have.properties [
          'id'
          'title'
          'description'
          'displayUrl'
          'url']
        done()
    it 'should return 100 results', (done) ->
      search.web 'Moz', {top: 100}, (err, results) ->
        should.not.exist err
        results.length.should.eql 91
        done()

  describe 'images', ->
    it 'should return results', (done) ->
      search.images 'Moz', (err, results) ->
        should.not.exist err
        results.length.should.eql 43
        results[0].should.have.properties [
          'id'
          'title'
          'url'
          'sourceUrl'
          'displayUrl'
          'width'
          'height'
          'size'
          'type'
          'thumbnail'
        ]
        results[0].thumbnail.should.have.properties [
          'url'
          'width'
          'height'
        ]
        done()

  describe 'videos', ->
    it 'should return results', (done) ->
      search.videos 'Moz', (err, results) ->
        should.not.exist err
        results.length.should.eql 46
        results[0].should.have.properties [
          'id'
          'title'
          'url'
          'displayUrl'
          'runtime'
          'thumbnail'
        ]
        results[0].thumbnail.should.have.properties [
          'url'
          'width'
          'height'
        ]
        done()

  describe 'news', ->
    it 'should return results', (done) ->
      search.news 'Moz', (err, results) ->
        should.not.exist err
        results.length.should.eql 50
        results[0].should.have.properties [
          'id'
          'title'
          'source'
          'url'
          'description'
          'date'
        ]
        done()
