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

  describe 'sanitizeQuery', ->
    it 'should put a phrase in quotes', (done) ->
      search.sanitizeQuery('Moz').should.eql '"Moz"'
      done()
    it 'should not change pre-quoted phrases', (done) ->
      search.sanitizeQuery('"Moz"').should.eql '"Moz"'
      done()
    it 'should normalize crazy whitespace', (done) ->
      search.sanitizeQuery(decodeURIComponent 'A%0AB%20%20%20C').should.eql '"A B C"'
      done()

  describe 'counts', ->
    it 'should return counts for all verticals', (done) ->
      search.counts 'Moz', (err, results) ->
        should.not.exist err
        results.should.eql
          web: 325
          image: 776
          video: 145
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
          'url'
        ]
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

  describe 'empty responses', ->
    it 'should not fail for web searches', (done) ->
      search.web '+"h>RL?gIg2U>0;m`/Q;Fhk67=!Pv184"', (err, results) ->
        should.not.exist err
        results.length.should.eql 0
        done()

    it 'should not fail for counts', (done) ->
      search.counts '+"h>RL?gIg2U>0;m`/Q;Fhk67=!Pv184"', (err, results) ->
        should.not.exist err
        results.should.eql
          web: 0
          image: 0
          video: 0
          news: 0
        done()
