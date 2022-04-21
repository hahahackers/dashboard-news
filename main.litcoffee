## Setup

We will use RSS from `vc.ru`, `dtf.ru` and `tjournal.ru`, popular Russian news websites

    source = 'vc.ru' # add dtf.ru and tjournal.ru

We will periodically fetch new entries.

    updateInterval = 5 * 60 # 5 min

## Fetching data

We need some libraries:

- We need some lib for HTTP requests

    fetch = require 'node-fetch'

- We also should be able to transform XML to JSON

    xml2js = require 'xml2js'

Function for fetching data, it will accept a source and one of two types:

- 'all' : fetch all news
- 'new' : fetch only fresh news

    getRSS = (source, type) ->
      response = await fetch "https://#{source}/rss/#{type}"
      xml = await do response.text
      obj = await xml2js.parseStringPromise xml

Mapping the response to our needs, returning a simple POJO

      title: obj.rss.channel[0].title[0]
      items: obj.rss.channel[0].item.map (item) ->
        title: item.title[0]
        link: item.link[0]
        guid: item.guid[0]._
        publishedAt: item.pubDate[0]

## UI

We need to format dates to human readable form. Let's do it using `date-fns`

    { formatDistanceToNowStrict, parse } = require 'date-fns'

    formatDate = (date) ->
      formatDistanceToNowStrict parse date, 'E, d MMM yyyy HH:mm:ss X', new Date()

    merge = (prev, next) ->
      next.reduce (acc, cur) ->
        acc[cur.guid] =
          guid: cur.guid
          title: cur.title
          link: cur.link
          publishedAt: formatDate cur.publishedAt
        acc
      , prev

Let's creat a UI for our watcher, we will use `react` as UI library and `ink` as our console React renderer.
We will have two components: one containing fetching logic and another with visuals

    { Fragment, useState, useEffect } = React = require 'react'
    { Box, Text } = require 'ink'

    FeedContainer = ({ source, type }) ->
      [count, setCount] = useState updateInterval
      [loading, setLoading] = useState true
      [title, setTitle] = useState ''
      [items, setItems] = useState {}

Update logic

      update = ->
        setLoading true

        data = await getRSS source, type

        setItems (prev) -> merge prev, data.items
        setTitle data.title
        setCount updateInterval
        setLoading false

Two effects, one for timer and one for update logic

      useEffect ->
        timer = setInterval ->
          setCount (prev) -> prev - 1
        , 1000

        -> clearInterval timer
      , []

      useEffect ->
        do update if count is updateInterval
        return
      , [count]

Rendering view

      return <Text>Loading</Text> if loading

      <Fragment>
        <Text>Update in {count} seconds</Text>
        <FeedView title={title} items={items} />
      </Fragment>

This component contains visuals

    FeedView = ({ title, items }) ->

      values = Object.values items

Calculating the padding for date column

      datePadding = Math.max (values.map (_) -> _.publishedAt.length)...

We sort by `guid` property

      byGuid = (a, b) -> b.guid - a.guid

      <Fragment>
        <Text>{title}</Text>
        {
          values
            .sort byGuid
            .map (item, ind) ->
              <Box key={item.guid}>
                <Text dimColor color="blue">https://{source}/{item.guid}</Text>
                <Text> </Text>
                <Text dimColor color="yellow">{item.publishedAt.padEnd datePadding}</Text>
                <Text> </Text>
                <Text>{item.title}</Text>
              </Box>
        }
      </Fragment>

Finally, let's render everything

    { render } = require 'ink'

    do console.clear

    render <FeedContainer source={source} type="all"/>
