irc = require "irc"

{ EventEmitter } = require 'events'

# Exchange

normalizePrice = (price) ->
  Math.round(parseFloat(price) * 100).toString(10).replace(/(\d{2})$/, ".$1")
normalizeName = (name) ->
  name.toLowerCase().replace(/[^a-z0-9]/g, "")

class Exchange extends EventEmitter
  constructor: (name) ->
    super()
    @name = name
    @trade =
      price: 0
      qty: 0
      time: new Date()

  update: (price, qty = 0) ->
    oldTrade = @trade
    @trade =
      price: normalizePrice price
      qty: qty
      time: new Date()
    console.log "UPDATE name=#{@name} " + ("#{k}=#{v}" for k,v of @trade).join(" ")
    @emit "updated", oldTrade, @trade

class ExchangeList extends EventEmitter
  constructor: (defaults = []) ->
    super()
    @list = []
    @get(name) for name in defaults

  get: (name) ->
    name = normalizeName(name)
    exchanges = (exchange for exchange in @list when exchange.name is name)
    if exchanges.length is 0
      @add new Exchange(name)
    else
      exchanges[0]

  add: (exchange) ->
    exchange.on "updated", (oldTrade, newTrade) =>
      @emit "exchangeUpdated", exchange, oldTrade, newTrade
    @list.push exchange
    exchange

# Sources

bitcoinWatchSource = (exchanges) ->
  user = "x" + Math.floor(Math.random() * (1 << 30)).toString(16)
  irc = new irc.Client "irc.freenode.net", user, channels: ["#bitcoin-watch"]

  irc.addListener 'message#bitcoin-watch', (from, message) ->
    message = message.replace(/\x03(?:\d{1,2}(?:,\d{1,2})?)?/g, "")
    match = message.match(/trade ([^:]+).*(\d+\.\d+).*BTC @  (\d+\.\d{2}).*USD ==/)
    if match
      [_, exchange, qty, price] = match
      exchanges.get(exchange).update price, qty

mtgoxSource = (exchanges) ->
  socket = require('socket.io-client').connect('https://socketio.mtgox.com/mtgox?Currency=USD')
  socket.on 'message', (message) ->
    if message.trade?.price_currency is "USD"
      exchanges.get("mtgox2").update message.trade.price, message.trade.amount

coinbaseSource = (exchanges) ->
  Coinbase = require "./coinbase"
  coinbase = new Coinbase()
  setInterval ->
    coinbase.buyPrice().then (buy) ->
      exchanges.get("coinbasebuy").update buy.amount
    coinbase.sellPrice().then (sell) ->
      exchanges.get("coinbasesell").update sell.amount
  , 10000

# Bot

frequency = parseInt(process.env["UPDATE_FREQUENCY"] or "60", 10)

config =
  channels: process.env["IRC_CHANNELS"].split(/\s+/g)
  server: process.env["IRC_SERVER"]
  user: process.env["IRC_USER"]

console.log "CONFIG", config

channels = []

bot = new irc.Client config.server, config.user, channels: config.channels
bot.on "join", (channel, who) ->
  console.log "JOIN", channel, who
  if who is config.user
    channels.push channel
bot.on 'error', (error) ->
  console.log "ERROR", error

exchanges = new ExchangeList()#["mtgox", "btce", "bitcoin24", "bitfloor"])#, "coinbase"])

updateTopic = ->
  now = new Date()
  message = (for exchange in exchanges.list
    if now - exchange.trade.time > 10*60*1000 or not exchange.trade.price
      "[#{exchange.name}]"
    else
      "[#{exchange.name} #{exchange.trade.price}]"
  ).join " "
  for channel in channels
    console.log 'TOPIC', channel, message
    bot.send 'TOPIC', channel, message

# last = null
# exchanges.on "exchangeUpdated", (exchange, oldTrade, newTrade) ->
#   now = new Date()
#   if now - last > 60*1000 #or Math.abs((oldTrade.price - newTrade.price) / oldTrade.price) > 0.10
#     last = now
#     updateTopic()

setInterval updateTopic, frequency*1000
setTimeout updateTopic, 30*1000

bitcoinWatchSource(exchanges)
mtgoxSource(exchanges)
coinbaseSource(exchanges)
