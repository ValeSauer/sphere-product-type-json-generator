{expect} = require 'chai'
Promise = require 'bluebird'
ProductTypeImporter = require '../../lib/product-type-import'
{SphereClient} = require 'sphere-node-sdk'
{ProjectCredentialsConfig} = require 'sphere-node-utils'

errMissingCredentials = 'Missing configuration in env variables'

argv =
  projectKey: process.env.SPHERE_PROJECT_KEY
  logSilent: true

testProductType = {
  "name": "top_and_shirts",
  "description": "Tops & Shirts",
  "attributes": [
    {
      "name": "designer",
      "label": {
        "de": "Designer",
        "en": "designer"
      },
      "type": {
        "name": "text"
      },
      "attributeConstraint": "SameForAll",
      "isRequired": false,
      "isSearchable": false,
      "inputHint": "SingleLine"
    },
    {
      "name": "materialComposition",
      "label": {
        "de": "Zusammensetzung Material",
        "en": "material composition"
      },
      "type": {
        "name": "ltext"
      },
      "attributeConstraint": "None",
      "isRequired": false,
      "isSearchable": false,
      "inputHint": "MultiLine"
    }
  ]
}

describe 'ProductTypeImporter', ->
  importer = null
  sphereClient = null

  before ->
    expect(argv.projectKey).to.be.a 'string', errMissingCredentials

    ProjectCredentialsConfig.create()
    .then (credentials) ->
      sphereCredentials = credentials.enrichCredentials
        project_key: argv.projectKey

      config =
        projectKey: sphereCredentials.project_key,
        clientId: sphereCredentials.client_id,
        clientSecret: sphereCredentials.client_secret

      importer = new ProductTypeImporter
      importer.init config

      options =
        config: sphereCredentials
      sphereClient = new SphereClient options

  beforeEach ->
    sphereClient.productTypes.fetch()
    .then (res) ->
      console.log "Deleting old product types", res.body.results.length
      Promise.map res.body.results, (productType) ->
        sphereClient.productTypes.byId(productType.id)
        .delete(productType.version)

  it 'should import product type', ->
    expect(importer).to.be.an 'object'
    expect(sphereClient).to.be.an 'object'

    sphereClient.productTypes.fetch()
    .then (res) ->
      expect(res.body.results.length).to.equal 0
      console.log "Importing product type using importer"
      importer.import {productTypes: [testProductType]}
    .then ->
      console.log "Product type imported - verifiing result"
      sphereClient.productTypes.fetch()
    .then (res) ->
      expect(res.body.results.length).to.equal 1

  it 'should not import wrong product type', (done) ->
    expect(importer).to.be.an 'object'
    expect(sphereClient).to.be.an 'object'

    delete testProductType.name
    importer.import {productTypes: [testProductType]}
    .then ->
      done "Importer wrong product type"
    .catch ->
      sphereClient.productTypes.fetch()
      .then (res) ->
        expect(res.body.results.length).to.equal 0
        done()
    return 0 # do not return promise