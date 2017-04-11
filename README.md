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
[ { title: 'Tutta Bella',
    description: 'The Northwest’s first certified Neapolitan pizzeria. ... Find out what is happening at your neighborhood Tutta Bella, learn about our partners, ...',
    displayUrl: 'https://tuttabella.com',
    url: 'https://www.bing.com/cr?IG=44525DED0AD248D6A4D456FFBA3CAD3D&CID=126EB96154286145212AB300557760BA&rd=1&h=Czc59koUIRW4FD93gPuLRozSc8ADBjCey3bC9afmymI&v=1&r=https%3a%2f%2ftuttabella.com%2f&p=DevEx,5038.1' },
  { title: 'Tutta Bella Neapolitan Pizzeria - Wallingford - 292 Photos ...',
    description: 'The inspiration for Tutta Bella Neapolitan Pizzeria stems from a passion for the authentic, fire-roasted pizzas born in Naples and found throughout Italy.',
    displayUrl: 'https://www.yelp.com/biz/tutta-bella-neapolitan-pizzeria...',
    url: 'https://www.bing.com/cr?IG=44525DED0AD248D6A4D456FFBA3CAD3D&CID=126EB96154286145212AB300557760BA&rd=1&h=WVzCmMsh9ZG6fiy95mMzywLGS1T7x4iM3mXOVqVo_DQ&v=1&r=https%3a%2f%2fwww.yelp.com%2fbiz%2ftutta-bella-neapolitan-pizzeria-wallingford-seattle&p=DevEx,5060.1' },
  { title: 'Tutta Bella Neapolitan Pizzeria - Issaquah - 136 Photos ...',
    description: '320 reviews of Tutta Bella Neapolitan Pizzeria - Issaquah "This is a really good little restaurant. The food here has been consistently good the last few times I\'ve been.',
    displayUrl: 'https://www.yelp.com/biz/tutta-bella-neapolitan-pizzeria-issaquah...',
    url: 'https://www.bing.com/cr?IG=44525DED0AD248D6A4D456FFBA3CAD3D&CID=126EB96154286145212AB300557760BA&rd=1&h=MAEKemzKxw-l7bZlWCVELifVeLVxn1ZaK4x11wPhGu0&v=1&r=https%3a%2f%2fwww.yelp.com%2fbiz%2ftutta-bella-neapolitan-pizzeria-issaquah-issaquah-2&p=DevEx,5075.1' },
  { title: 'Tutta Bella Neapolitan Pizzeria - Home | Facebook',
    description: 'Tutta Bella Neapolitan Pizzeria. 3,436 likes · 30 talking about this. Tutta Bella Neapolitan Pizzeria is the Northwest\'s first certified authentic...',
    displayUrl: 'https://www.facebook.com/TuttaBellaNeapolitanPizzeria',
    url: 'https://www.bing.com/cr?IG=44525DED0AD248D6A4D456FFBA3CAD3D&CID=126EB96154286145212AB300557760BA&rd=1&h=4iDqNf9EuGZ0kxNPo_U6Ysvtf9MFNBTUyWfEohw-aIw&v=1&r=https%3a%2f%2fwww.facebook.com%2fTuttaBellaNeapolitanPizzeria&p=DevEx,5089.1' },
  { title: 'Tutta Bella Neapolitan Pizzeria - Seattle - Zomato',
    description: 'Tutta Bella Neapolitan Pizzeria Seattle; Tutta Bella Neapolitan Pizzeria, Fremont; Get Menu, Reviews, Contact, Location, Phone Number, Maps and more for Tutta Bella ...',
    displayUrl: 'https://www.zomato.com/seattle/tutta-bella-neapolitan-pizzeria-fremont',
    url: 'https://www.bing.com/cr?IG=44525DED0AD248D6A4D456FFBA3CAD3D&CID=126EB96154286145212AB300557760BA&rd=1&h=37j-6zU-jJqHt0ouy4TqXOasoluj2TCYMhGdfLOxXB4&v=1&r=https%3a%2f%2fwww.zomato.com%2fseattle%2ftutta-bella-neapolitan-pizzeria-fremont&p=DevEx,5107.1' } ]
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
  [ { title: '...',
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
  [ { title: '...',
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
  [ { title: '...',
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
  [ { title: '...',
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
* Improve pagination handling from legacy methods
* Add debugging tips and tricks
* Better API error messages
* Adjust HTTPS max sockets based on concurrent level

Changes
-------

* 1.0.1
  * Initial support for all Bing Search API sources
* 5.0.1
  * Revised support for the new Bing API v5
