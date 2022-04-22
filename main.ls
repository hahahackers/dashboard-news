# We will use RSS from `vc.ru`m a popular Russian news website
source = 'vc.ru'

# We want to periodically fetch new entries
update-interval = 5 * 60 # 5 minutes

# -- Fetching data ---------------------------------------------------------------------------------

# We need some libraries: `fetch` for HTTP requests...
require! 'node-fetch': fetch

# ... and we also should be able to transform XML to JSON
require! xml2js

# Function for fetching data, it will accept a source and one of two types:
# 'all' will fetch all news and 'new' for only fresh news

get-RSS = (source, type) ->>
    response = await fetch "https://#{source}/rss/#{type}"
    xml = await response.text!
    obj = await xml2js.parse-string-promise xml

# Mapping the response to our needs, returning a simple POJO

    let entry = obj.rss.channel[0]
        title: entry.title[0]
        items: entry.item.map (item) ->
            title: item.title[0]
            link: item.link[0]
            guid: item.guid[0]._
            published-at: item.pub-date[0]

# -- UI --------------------------------------------------------------------------------------------

# We need to format dates to human readable form. Let's do it using `date-fns`

require! 'date-fns': { format-distance-to-now-strict, parse }

format-date = (date) -> 
    parse date, 'E, d MMM yyyy HH:mm:ss X', do Date.now
    |> format-distance-to-now-strict

merge = (prev, next) -> 
    for item in next
        prev[item.guid] = 
            guid: item.guid
            title: item.title
            link: item.link
            published-at: item.published-at |> format-date
    prev

# Let's creat a UI for our watcher, we will use `react` as UI library and `ink` as our console React renderer.
# We will have two components: one containing fetching logic and another with visuals

require! react: { Fragment, use-state, use-effect}: React
require! ink: { Box, Text }

# Lets change argument positions in useEffect fn for convenience

rearg = (fn, ids) -> (...args) -> fn(...ids.map (i) -> args[i])

use-effect = rearg use-effect, [1 0]
interval = rearg set-interval, [1 0]

# First component will serve as a container for all the logic

Feed-Container = ({ source, type }) ->
    [loading, set-loading] = use-state true
    [count, set-count]     = use-state update-interval
    [title, set-title]     = use-state ''
    [items, set-items]     = use-state {}

# Update logic

    update = ->>
        set-loading true
        data = await get-RSS source, type
        set-items (prev) -> merge prev, data.items
        set-title data.title
        set-count update-interval
        set-loading false

# Two effects, one for timer and one for update logic

    use-effect [] ->
        timer = interval 1000 -> set-count (--)
        -> clear-interval timer

    use-effect [count] !->
        switch count    
            when 0 then set-count update-interval
            when update-interval then do update

# Rendering view

    return ``<Text>Loading...</Text>`` if loading

    ``<Fragment>
        <Text>Update in {count} seconds</Text>
        <FeedView title={title} items={items} />
    </Fragment>``

FeedView = ({ title, items }) ->
    values = Object.values items
    
    date-padding = Math.max ...values.map (.published-at.length)

# Let's sort by guid

    by-guid = (a, b) -> b.guid - a.guid
    
    list = values.sort by-guid .map (item, ind) ->
        let published-at = item.published-at.pad-end date-padding
            ``<Box key={item.guid}>
                <Text dimColor color="blue">https://{source}/{item.guid}</Text>
                <Text> </Text>
                <Text dimColor color="yellow">{publishedAt}</Text>
                <Text> </Text>
                <Text>{item.title}</Text>
            </Box>``

    ``<Fragment>
        <Text>{title}</Text>
        {list}
    </Fragment>``

# Finally, let's render everything

require! ink: { render }

do console.clear

render ``<FeedContainer source={source} type="all" />``
