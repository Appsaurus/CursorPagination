<p align="center">
	<img src="CursorPaginationLogo.png">
</p>

# CursorPagination
![Swift](http://img.shields.io/badge/swift-5.0-brightgreen.svg)
![Vapor](http://img.shields.io/badge/vapor-3.0-brightgreen.svg)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
![License](http://img.shields.io/badge/license-MIT-CCCCCC.svg)

CursorPagination is a library for Vapor's Fluent that allows you to paginate queries using an opaque cursor. If you are looking for offset based pagination for Fluent, check out [Pagination](https://github.com/vapor-community/pagination). If you're not sure what cursor pagination is, or whether you need cursor or offset pagination, I recommend this great [writeup](https://slack.engineering/evolving-api-pagination-at-slack-1c1f644f8e12) from the Slack team explaining the difference between the two, and the pros and cons of each.

## Installation

**CursorPagination** is available through [Swift Package Manager](https://swift.org/package-manager/). To install, add the following to your Package.swift file.

```swift
let package = Package(
    name: "YourProject",
    dependencies: [
        ...
        .package(url: "https://github.com/Appsaurus/CursorPagination", from: "0.1.0"),
    ],
    targets: [
      .target(name: "YourApp", dependencies: ["CursorPagination", ... ])
    ]
)
        
```
## Usage
Check the app included in this project for a complete example. Here are some of the basics:

**1. Import the library**

```swift
import CusorPagination
```

**2. Extend your model class to adopt CusorPaginatable protocol**

You can simply declare the protocol adoption and inherit the default implementations.

```swift
extension ExampleModel: CursorPaginatable{}
```

Or you can set some default configurations by implementing any of the following static class vars.

```swift
extension ExampleModel: CursorPaginatable{
	public static var defaultPageSorts: [CursorSort<ExampleModel>] {
		return [idKey.descendingSort]
	}
	public static var defaultPageSize: Int {
		return 20
	}

	public static var maxPageSize: Int? {
		return 50
	}
}
```

**3. Setup your routes**

Setup routes to return a `Future<CursorPage<YourModel>>`. When you run your query, simply call `paginate(request:  sorts: )` on your class or on a QueryBuilder.

```swift
router.get("modelsByDate") { request -> Future<CursorPage<ExampleModel>> in
	return try ExampleModel.paginate(request: request,
					 sorts: .descending(\.dateField))
}
```

On your first request, omitting a cursor tells the method that you are starting at the first page.

`curl "http://localhost:8080/modelsByDate?limit=5"`

Results in:


```javascript
{  
   "remaining":45,
   "data":[  
      {  
         "booleanField":false,
         "id":10,
         "stringField":"Hammes Glen",
         "doubleField":718.52944714909995,
         "dateField":"2102-06-07T12:58:40Z",
         "intField":82
      },
      {  
         "booleanField":false,
         "id":11,
         "stringField":"Stracke Green",
         "doubleField":808.52215080719998,
         "dateField":"2094-08-08T15:32:25Z",
         "intField":714
      },
      {  
         "intField":789,
         "id":30,
         "dateField":"2093-01-24T07:06:53Z",
         "doubleField":992.49123409219999,
         "booleanField":true,
         "stringField":"Schowalter Branch",
         "optionalStringField":"15"
      },
      {  
         "intField":282,
         "id":38,
         "dateField":"2092-03-01T03:59:20Z",
         "doubleField":194.4565969041,
         "booleanField":true,
         "stringField":"Ignacio Springs",
         "optionalStringField":"20"
      },
      {  
         "booleanField":true,
         "id":32,
         "stringField":"Braun Rapid",
         "doubleField":445.48755242620001,
         "dateField":"2078-05-13T15:50:20Z",
         "intField":583
      }
   ],
   "nextPageCursor":"W3sia2V5IjoiZGF0ZUZpZWxkIiwidmFsdWUiOjMzODQ2Nzc4NjgsImRpcmVjdGlvbiI6ImRlc2NlbmRpbmcifSx7ImtleSI6ImlkIiwidmFsdWUiOjQ2LCJkaXJlY3Rpb24iOiJhc2NlbmRpbmcifV0="
}
```

Then use the `nextPageCursor` in your next request:

`curl "http://localhost:8080/modelsByDate?limit=5&cursor=W3sia2V5IjoiZGF0ZUZpZWxkIiwidmFsdWUiOjMzODQ2Nzc4NjgsImRpcmVjdGlvbiI6ImRlc2NlbmRpbmcifSx7ImtleSI6ImlkIiwidmFsdWUiOjQ2LCJkaXJlY3Rpb24iOiJhc2NlbmRpbmcifV0="`

```javascript
{  
   "remaining":40,
   "data":[  
      {  
         "booleanField":false,
         "id":46,
         "stringField":"Aditya Crossroad",
         "doubleField":226.63376066519999,
         "dateField":"2077-04-03T12:17:48Z",
         "intField":149
      },
      {  
         "booleanField":true,
         "id":18,
         "stringField":"Emmitt Ridges",
         "doubleField":90.362315319999993,
         "dateField":"2074-09-14T07:46:27Z",
         "intField":990
      },
      {  
         "booleanField":true,
         "id":27,
         "stringField":"Evelyn Rest",
         "doubleField":371.72649320490001,
         "dateField":"2072-11-21T19:26:05Z",
         "intField":77
      },
      {  
         "intField":351,
         "id":45,
         "dateField":"2071-04-18T00:59:09Z",
         "doubleField":45.889304030200002,
         "booleanField":true,
         "stringField":"Fisher Trail",
         "optionalStringField":"24"
      },
      {  
         "intField":476,
         "id":25,
         "dateField":"2070-04-10T15:16:10Z",
         "doubleField":810.14490844919999,
         "booleanField":false,
         "stringField":"Paucek Plains",
         "optionalStringField":"12"
      }
   ],
   "nextPageCursor":"W3sia2V5IjoiZGF0ZUZpZWxkIiwidmFsdWUiOjMwOTM3NTk5MzcsImRpcmVjdGlvbiI6ImRlc2NlbmRpbmcifSx7ImtleSI6ImlkIiwidmFsdWUiOjYsImRpcmVjdGlvbiI6ImFzY2VuZGluZyJ9XQ=="
}
```
When there are no more results, a cursor will not be returned.


### Compound Sorts

Sorting on multiple properties works as well.

**NOTE:**

> In order to break ties, the last sort must be on a unique property, otherwise a sort on a default unique property (Fluent id) will be applied.

```swift
router.get("modelsByBooleanAndString") { request -> Future<CursorPage<ExampleModel>> in
	return try ExampleModel.paginate(request: request,
					 sorts: .descending(\.booleanField), .ascending(\.stringField))
}
```

### Dynamic Sorting

You can allow the client to dynamically dictate how the results are sorted via query parameters. 

**⚠️ WARNING:**

> Because the dynamic sorting API has no way to resolve KeyPaths from string based parameters, it uses runtime reflection to build the cursor. You may not want to use this API in production until Swift ABI is stable.

Apply each sort via the `sort[]` and `order[]` parameters like so:

```swift
router.get("dynamicModels") { request -> Future<CursorPage<ExampleModel>> in
	return try ExampleModel.paginate(dynamicRequest: request)
}
```

`curl "http://localhost:8080/dynamicModels?limit=5&sort%5B%5D=booleanField&order%5B%5D=descending&sort%5B%5D=stringField&order%5B%5D=ascending"`


### TODO

- [x] Optional support
- [x] Compound sorts
- [x] Dynamic sorting
- [ ] Allow for additional filters on queries (may already work, needs to be tested)
- [ ] Aggregate support (might be some use cases here)
- [ ] Nil sort order preference
- [ ] Allow for customization of CursorPage's JSON structure
- [ ] Integrate CircleCI
- [ ] Explore database specific optimized implementations (benchmark first to see if needed)

## Contributing

We would love you to contribute to **CursorPagination**, check the [CONTRIBUTING](https://github.com/Appsaurus/CursorPagination/blob/master/CONTRIBUTING.md) file for more info.

## License

**CursorPagination** is available under the MIT license. See the [LICENSE](https://github.com/Appsaurus/CursorPagination/blob/master/LICENSE.md) file for more info.
