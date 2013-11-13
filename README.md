pricebot
========

IRC bot for reporting Bitcoin exchange prices

Setup
-----

When running locally with `foreman` create a `.env` file like the following:

    IRC_SERVER=irc.freenode.net
    IRC_USER=mychannel_pricebot
    IRC_CHANNELS=#mychannel
    UPDATE_FREQUENCY=300

Then run:

    foreman start
