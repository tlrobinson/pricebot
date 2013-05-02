#!/usr/bin/env coffee

q = require "q"
http = require "q-io/http"

# npm install q q-io

class Coinbase
  constructor: (apiKey) ->
    @apiKey = apiKey
  accountBalance: ->
    http.request(url: "https://coinbase.com/api/v1/account/balance?api_key=#{@apiKey}").then bodyReadParse
  buyPrice: ->
    http.request(url: "https://coinbase.com/api/v1/prices/buy").then bodyReadParse
  sellPrice: ->
    http.request(url: "https://coinbase.com/api/v1/prices/sell").then bodyReadParse
  buy: (qty) ->
    body = JSON.stringify
      api_key: @apiKey
      qty: qty
    http.request(
      url: "https://coinbase.com/api/v1/buys"
      headers:
        "Content-Type": "application/json"
        "Content-Length": "#{body.length}"
      method: "POST"
      body: [body]
    ).then bodyReadParse

bodyReadParse = (response) ->
  response.body.read().then (body) ->
    JSON.parse body.toString('utf-8')

module.exports = Coinbase

if require.main is module
  coinbase = new Coinbase()
  coinbase.buyPrice().then (price) ->
    console.log price
