Bing Search API for NodeJS
==========================
[![Build Status](https://travis-ci.org/seomoz/bing-search.svg)](https://travis-ci.org/seomoz/bing-search)

Features
--------

* Support core [Bing API v5](https://msdn.microsoft.com/en-us/library/mt604056.aspx) verticals:
    * [Web](https://msdn.microsoft.com/en-us/library/mt711415.aspx)
    * [Image](https://msdn.microsoft.com/en-us/library/mt711418.aspx)
    * [Video](https://msdn.microsoft.com/en-us/library/mt711417.aspx)
    * [News](https://msdn.microsoft.com/en-us/library/mt711408.aspx)
* Retrieve counts for each vertical with a simple set of async requests.
* Abstracted pagination for large results.
* Configurable concurrent requests for results sets larger than 25 results.
* Normalized JSON results.
* Uses `gzip` out-of-the-box by default.

Getting Started
---------------

1. Sign-up for a [Microsoft Cognitive Services](https://www.microsoft.com/cognitive-services/en-us/sign-up) account.
2. Use the [API Testing Console](https://dev.cognitive.microsoft.com/docs/services/56b43eeccf5ff8098cef3807/operations/56b4447dcf5ff8098cef380d/console) to see the results you can expect.
3. Grab the API key from [Microsoft Azure's dashboard](https://portal.azure.com/#blade/HubsExtension/Resources/resourceType/Microsoft.Resources%2Fresources).

Install
-------

```bash
$ npm install git://github.com/seomoz/bing-search.git --save 
```

Usage
-----

Basic example:
```javascript
var Search = require('bing.search');
var util = require('util');

search = new Search('account_key_123');

search.web('Tutta Bella Neapolitan Pizzeria',
  {top: 5},
  function(err, results) {
    console.log(util.inspect(results, 
      {colors: true, depth: null}));
  }
);
```

Output:
```javascript
[ { id: 'Czc59koUIRW4FD93gPuLRozSc8ADBjCey3bC9afmymI',
    title: 'Tutta Bella',
    description: 'We use the finest imported and locally sourced ingredients along with centuries-old, artisan traditions to bring the definitive Neapolitan pizza experience to our guests.',
    url: 'https://www.bing.com/cr?IG=F46CAFD4DAF240DC8816EF32124582DE&CID=048B2A80E639669909DF20E2E766671C&rd=1&h=Czc59koUIRW4FD93gPuLRozSc8ADBjCey3bC9afmymI&v=1&r=https%3a%2f%2ftuttabella.com%2f&p=DevEx,5039.1',
    displayUrl: 'https://tuttabella.com' },
  { id: 'WVzCmMsh9ZG6fiy95mMzywLGS1T7x4iM3mXOVqVo_DQ',
    title: 'Tutta Bella Neapolitan Pizzeria - Wallingford - 292 Photos ...',
    description: '591 reviews of Tutta Bella Neapolitan Pizzeria - Wallingford "Tutta Bella is a bit of an institution here in Seattle, and I\'m glad I finally came by to check it out!',
    url: 'https://www.bing.com/cr?IG=F46CAFD4DAF240DC8816EF32124582DE&CID=048B2A80E639669909DF20E2E766671C&rd=1&h=WVzCmMsh9ZG6fiy95mMzywLGS1T7x4iM3mXOVqVo_DQ&v=1&r=https%3a%2f%2fwww.yelp.com%2fbiz%2ftutta-bella-neapolitan-pizzeria-wallingford-seattle&p=DevEx,5062.1',
    displayUrl: 'https://www.yelp.com/biz/tutta-bella-neapolitan-pizzeria...' },
  { id: '4iDqNf9EuGZ0kxNPo_U6Ysvtf9MFNBTUyWfEohw-aIw',
    title: 'Tutta Bella Neapolitan Pizzeria - Home | Facebook',
    description: 'Tutta Bella Neapolitan Pizzeria is the Northwest\'s first certified authentic Neapolitan pizzeria. 3,432 people like this and 3,160 people follow this. About See All.',
    url: 'https://www.bing.com/cr?IG=F46CAFD4DAF240DC8816EF32124582DE&CID=048B2A80E639669909DF20E2E766671C&rd=1&h=4iDqNf9EuGZ0kxNPo_U6Ysvtf9MFNBTUyWfEohw-aIw&v=1&r=https%3a%2f%2fwww.facebook.com%2fTuttaBellaNeapolitanPizzeria&p=DevEx,5076.1',
    displayUrl: 'https://www.facebook.com/TuttaBellaNeapolitanPizzeria' },
  { id: 'MAEKemzKxw-l7bZlWCVELifVeLVxn1ZaK4x11wPhGu0',
    title: 'Tutta Bella Neapolitan Pizzeria - Issaquah - 136 Photos ...',
    description: '321 reviews of Tutta Bella Neapolitan Pizzeria - Issaquah "This is a really good little restaurant. The food here has been consistently good the last few times I\'ve been.',
    url: 'https://www.bing.com/cr?IG=F46CAFD4DAF240DC8816EF32124582DE&CID=048B2A80E639669909DF20E2E766671C&rd=1&h=MAEKemzKxw-l7bZlWCVELifVeLVxn1ZaK4x11wPhGu0&v=1&r=https%3a%2f%2fwww.yelp.com%2fbiz%2ftutta-bella-neapolitan-pizzeria-issaquah-issaquah-2&p=DevEx,5092.1',
    displayUrl: 'https://www.yelp.com/biz/tutta-bella-neapolitan-pizzeria-issaquah...' },
  { id: 'k4fp-oYp7UsAl2kbopZWnj46jdIkioxitq-B416gb9g',
    title: 'Tutta Bella Neapolitan Pizzeria, Columbia City, Seattle ...',
    description: 'Tutta Bella Neapolitan Pizzeria Seattle; Tutta Bella Neapolitan Pizzeria, Columbia City; Get Menu, Reviews, Contact, Location, Phone Number, Maps and more for Tutta ...',
    url: 'https://www.bing.com/cr?IG=F46CAFD4DAF240DC8816EF32124582DE&CID=048B2A80E639669909DF20E2E766671C&rd=1&h=k4fp-oYp7UsAl2kbopZWnj46jdIkioxitq-B416gb9g&v=1&r=https%3a%2f%2fwww.zomato.com%2fseattle%2ftutta-bella-neapolitan-pizzeria-columbia-city&p=DevEx,5110.1',
    displayUrl: 'https://www.zomato.com/seattle/tutta-bella-neapolitan-pizzeria...' } ]

```

### new Search(accountKey, [parallelLimit], [useGzip])

The `accountKey` is the Bing Search API account key provided by Microsoft
Cognitive Services. `parallelLimit`, default `10`, is the number of search
results pages fetched in parallel for a given query. `useGzip`, default
`true`, enables the use of `gzip` on HTTP requests.

Available methods:

* `counts(query, [options], callback)` . `query` is the search query. `options` is a dictionary with permissible values below -- it can be ommitted. `callback` takes an error and a results object.  

  The following options can be provided:
  * `market`

  Format of results to callback:
  ```javascript
  { web: 334,
    images: 20400,
    videos: 33400,
    news: 1460 }
  ```

* `web(query, [options], callback)` "Web" only search. `query` is the search query. `options` is a dictionary with permissible values below -- it can be ommitted. `callback` takes an error and a results object.  

  The following options can be provided:
  * `top` default is 50
  * `market`

  Format of results to callback:
  ```javascript
  [ { id: '...',
      title: '...',
      description: '...',
      url: 'http://...',
      displayUrl: '...' },
     ...
  ]

  ```
* `images(query, [options], callback)` "Image" only search. `query` is the search query. `options` is a dictionary with permissible values below -- it can be ommitted. `callback` takes an error and a results object.

  The following options can be provided:
  * `top` default is 50
  * `market`

  Format of results to callback:
  ```javascript
  [ { id: '...',
      title: '...',
      url: 'http://...',
      sourceUrl: 'http://...',
      displayUrl: '...',
      width: 1025,
      height: 1600,
      size: '12345 B',
      type: 'jpeg',
      thumbnail:
      { url: 'http://...',
        width: 192,
        height: 300 }
    },
     ...
  ]
  ```
* `videos(query, [options], callback)` "Video" only search. `query` is the search query. `options` is a dictionary with permissible values below -- it can be ommitted. `callback` takes an error and a results object.

  The following options can be provided:
  * `top` default is 50
  * `market`

  Format of results to callback:
  ```javascript
  [ { id: '...',
      title: '...',
      url: 'http://...',
      displayUrl: '...',
      runtime: 'PT2M50S',
      thumbnail:
      { url: 'http://...',
        width: 192,
        height: 300 }
     ...
  ]
  ```
* `news(query, [options], callback)` "News" only search. `query` is the search query. `options` is a dictionary with permissible values below -- it can be ommitted. `callback` takes an error and a results object.

  The following options can be provided:
  * `top` default is 15
  * `market`

  Format of results to callback:
  ```javascript
  [ { id: '...',
      title: '...',
      source: '...',
      url: 'http://...',
      description: '...',
      date: [Date Object] },
     ...
  ]
  ```

Debugging
---------


TODOs
-----

* Implement spelling suggestions, related searches, and composite queries
* More support for custom options (lat/long, vertical-specific filters, etc.)
* Better API error messages
* Add debugging tips and tricks
* Adjust HTTPS max sockets based on concurrent level

Changes
-------

* 1.0.1 [no longer working]
  * Initial support for all Bing Search API sources
* 5.0.1
  * Revised support for the new Bing API v5
  * Upgrade to this version is required, since Bing [retired v2 of their API](
  https://msdn.microsoft.com/en-us/library/mt707570.aspx) which was used by
  v1.0.1 of this library.

Upgrading
---------

A number of changes, some breaking, have been made between v1.0.1 and v5.0.1
to support the new Bing API v5. Here is a summary of said changes:
* Some response keys have changed values and others were removed completely:
  * The `size` and `type` keys have been removed from all `thumbnail` objects
  (both `image`s and `video`s).
  * `image.size` has changed to "\<size\> \<units\>".
  * `image.type` no longer includes a namespace (i.e. jpeg, not image/jpeg).
  * `video.duration` has changed from seconds to a [duration-formatted string](
  https://en.wikipedia.org/wiki/ISO_8601#Durations).
  * The unique `id` is no longer returned by Bing API, but we still parse this
  out of the URL. The library only relies on this for duplication protection.
* The `count()` method returns different verticals:
  * `web` -> stayed the same
  * `image` -> `images`
  * `video` -> `videos`
  * `news` -> stayed the same
  * `spelling` -> deleted
* `related()`/`spelling()`/`composite()` are, for now, not included.

Additional notes to keep in mind:
* Pagination functions differently than before. Instead of `$top`/`$skip` vars,
`count`/`offset` are now used. We use `25` for our count (which seems to return
the best results) and then continue to use the `top` option (with the same `50`
default) to limit the total number of results collected from the API during
pagination.
* Composite searching is not available in the capacity it was before.
Previously, you were able to search multiple verticals at once and retrieve
relevant results. Now, a comparable request will return a mixed set of results
depending on what verticals match best (similar to what a human would expect);
this isn't useful for our purposes. To keep functionality similar, we must make
parallel requests for our `count()` and [the not-yet implemented] `composite()`
methods.
