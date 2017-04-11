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

  describe 'counts', ->
    it 'should return counts for all verticals', (done) ->
      search.counts 'Tutta Bella Neapolitan Pizza', (err, results) ->
        should.not.exist err
        results.should.eql
          web: 569
          images: 432
          videos: 252
          news: 1760
        done()

  describe 'web', ->
    it 'should return results', (done) ->
      search.web 'Tutta Bella Neapolitan Pizza', (err, results) ->
        should.not.exist err
        results.length.should.eql 50
        results[0].should.have.properties [
          'title'
          'description'
          'displayUrl'
          'url']
        done()
    it 'should return 100 results', (done) ->
      search.web 'Tutta Bella Neapolitan Pizza', {top: 100}, (err, results) ->
        should.not.exist err
        results.length.should.eql 100
        done()

  describe 'images', ->
    it 'should return results', (done) ->
      search.images 'Tutta Bella Neapolitan Pizza', (err, results) ->
        should.not.exist err
        results.length.should.eql 50
        results[0].should.have.properties [
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
      search.videos 'Tutta Bella Neapolitan Pizza', (err, results) ->
        should.not.exist err
        results.length.should.eql 50
        results[0].should.have.properties [
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
      search.news 'Tutta Bella Neapolitan Pizza', (err, results) ->
        should.not.exist err
        results.length.should.eql 50
        results[0].should.have.properties [
          'title'
          'source'
          'url'
          'description'
          'date'
        ]
        done()
