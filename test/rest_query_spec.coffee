
nock = require 'nock'

RQ = require '../restQuery'
request = require 'request'

chai = require 'chai'
should = chai.Should()
cap = require 'chai-as-promised'
chai.use cap
Q = require 'q'


TEST_ROOT_URL = "http://blah.bar"


describe 'RestQuery', ->

  testObj = {
    test_field: 42,
    test_field2: [],
    id: 11
  }

  beforeEach ->
    nock(TEST_ROOT_URL)
      .get("/user/123456.json")
      .reply(200, testObj)

  afterEach ->
    # Make sure we're not leaking mocked replies between tests.
    nock.cleanAll()

  describe "calling 'from'", ->

    it 'creates an instance', ->
      rq = RQ.from("#{TEST_ROOT_URL}/user/123456.json")
      should.exist rq


  describe "calling 'get'", ->

    describe "for a field that exists", ->
      it "returns a promise for the requested field", (done) ->
        RQ.from("#{TEST_ROOT_URL}/user/123456.json")
          .get('test_field')
          .should.eventually.equal(testObj['test_field'])
          .notify(done)

    describe "with '.' as parameter", ->
      it "returns the whole object", (done) ->
        RQ.from("#{TEST_ROOT_URL}/user/123456.json")
          .get('.')
          .should.eventually.eql(testObj)
          .notify(done)


    describe "for a field that does not exist", ->
      it "returns a rejected promise", (done) ->
        RQ.from("#{TEST_ROOT_URL}/user/123456.json")
          .get('nonexistent_field')
          .should.be.rejected
          .notify(done)


  describe "calling 'via'", ->

    beforeEach ->
      nock(TEST_ROOT_URL)
        .get("/project/11.json")
        .reply 200, {name: "test_project", other_id: 18}

    describe "when the middle object exists", ->

      it "returns the requested field", (done) ->
        RQ.from("#{TEST_ROOT_URL}/user/123456.json")
          .via("/project/11.json")
          .get('name')
          .should.eventually.equal("test_project")
          .notify(done)

    describe "when using placeholder", ->

      it "returns the requested field", (done) ->
        RQ.from("#{TEST_ROOT_URL}/user/123456.json")
          .via("/project/{id}.json")
          .get('name')
          .should.eventually.equal("test_project")
          .notify(done)

    describe 'following a two-level link', ->

      beforeEach ->
        nock(TEST_ROOT_URL)
          .get("/second_level/18.json")
          .reply 200, {name: '2nd-level'}

      it "returns the requested field", (done) ->
        RQ.from("#{TEST_ROOT_URL}/user/123456.json")
          .via("/project/{id}.json")
          .via("/second_level/{other_id}.json")
          .get('name')
          .should.eventually.equal("2nd-level")
          .notify(done)

    describe "when the middle object does not exist", ->

      beforeEach ->
        nock(TEST_ROOT_URL)
          .get("/project/0.json")
          .reply 404, {}

      it "returns a rejected promise", (done) ->
        RQ.from("#{TEST_ROOT_URL}/user/123456.json")
          .via("/project/0.json")
          .get('name')
          .should.be.rejected
          .notify(done)

    describe "when the middle object returns HTTP 500", ->

      beforeEach ->
        nock(TEST_ROOT_URL)
          .get("/project/0.json")
          .reply 500, {}

      it "returns a rejected promise", (done) ->
        RQ.from("#{TEST_ROOT_URL}/user/123456.json")
          .via("/project/0.json")
          .get('name')
          .should.be.rejected
          .notify(done)

    describe "when first object returns HTTP 500", ->

      it "returns a rejected promise", (done) ->
        nock(TEST_ROOT_URL)
          .get("/user/fail.json")
          .reply 500, {err: 'test error'}

        RQ.from("#{TEST_ROOT_URL}/user/fail.json")
          .via("/project/0.json")
          .get('name')
          .should.be.rejected
          .notify(done)

  describe "forking a query", ->

    it "does not send GET requests for the shared part of the query twice", (done) ->
      nock(TEST_ROOT_URL)
        .get("/project/11.json")
        .reply(200, {name: "test_project", other_id: 18})
        .get("/second_level/18.json")
        .reply(200, {name: '2nd-level'})

      query = RQ.from("#{TEST_ROOT_URL}/user/123456.json")
        .via("/project/{id}.json")

      p1 = query.get 'name'
      p2 = query.via("/second_level/{other_id}.json")
        .get('name')

      Q.all([p1, p2]).should.eventually.eql(['test_project', '2nd-level'])
        .notify(done)

