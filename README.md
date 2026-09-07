# GraphQL Schema 3

[![Build](https://img.shields.io/github/actions/workflow/status/raphrmx/graphql_schema3/ci.yml?branch=main&label=build)](https://github.com/raphrmx/graphql_schema3/actions/workflows/ci.yml)
[![Maintainer](https://img.shields.io/badge/Maintainer-Raphael-purple)](https://comapps.be)
[![License](https://img.shields.io/badge/Licence-BSD--3--Clause-blue)](LICENSE)

An implementation of GraphQL's type system in Dart, with no dependency beyond `collection` and
`source_span`. Supports any platform where Dart runs. The decisions made in the design of this library were done to make the experience as similar to the JavaScript reference implementation as possible, and to also correctly implement the official specification.

Contains functionality to build *all* GraphQL types:

* `String`
* `Int`
* `Float`
* `Boolean`
* `GraphQLObjectType`
* `GraphQLUnionType`
* `GraphQLEnumType`
* `GraphQLInputObjectType`
* `Date` - ISO-8601 Date string, deserializes to a Dart `DateTime` object

Of course, for a full description of GraphQL's type system, see the official [GraphQL Specification](https://spec.graphql.org/). Mostly analogous to [graphql-js](https://graphql.org/graphql-js/type/); many names are verbatim.

## Where this comes from

This package is a fork of the GraphQL stack maintained as part of
[Angel3](https://github.com/dukefirehawk/angel), which itself descends from the
`graphql_*` packages Tobe O wrote for Angel. The fork is taken from the `2`
line; the original BSD-3-Clause licence and its copyright notice are kept
verbatim in [LICENSE](LICENSE), and the bulk of the type system, the parser and
the execution algorithm are still that work.

Why fork at all. Two reasons, and only the second one still holds:

- Upstream had stopped moving while the projects depending on it had not.
  Development there has since resumed, but by then the two lines had diverged
  far enough that merging back would cost more than it returns.
- The stack was pinned to `angel3_*`, and `angel3_*` decided which `analyzer`
  and which Dart SDK everything downstream could use. That is what held the
  generator seven `analyzer` majors back for months. Cutting the tie was the
  point of the `3` line.

So: the `3` line does not track upstream and does not merge from it. It is
maintained on its own, with three rules - as few dependencies as possible, no
dependency that dictates the SDK, and no behaviour without a test covering it.

## What version 3 changed

Two dependencies, `collection` and `source_span`.

Six bugs, all of them reachable from a client request:

- Validating an unknown enum literal raised `Bad state: No element` instead of
  returning a failed `ValidationResult`. For a string-valued enum, built with
  `enumTypeFromStrings`, every literal took that path, so any client sending an
  unrecognised value crashed the resolver.
- A field whose input had the wrong type raised a cast error while validating
  an object rather than reporting the mismatch.
- `Float` rejected an integer literal. The specification coerces an integer to
  `Float`, and only in that direction.
- `GraphQLFieldInput.operator ==` compared `other.defaultValue` with itself, so
  two inputs differing only by their default compared as equal.
- Four types hashed the identity of their field list while comparing its
  contents, so two equal instances could carry different hash codes. That
  breaks the `Object` contract and, with it, any `Set` or `Map` keyed on a type.
- `GraphQLObjectType.hashCode` and `GraphQLInputObjectType.hashCode` folded
  `name` in twice and never `description`.

Also: `quiver` removed, its `hash2` / `hash3` / `hash4` replaced by
`Object.hash`; and a test suite of 41 tests, where there were none.

The full list is in [CHANGELOG.md](CHANGELOG.md).

## Usage

It's easy to define a schema with the [helper functions](#helpers):

```dart
final GraphQLSchema todoSchema = GraphQLSchema(
    query: objectType('Todo', [
  field('text', graphQLString.nonNullable()),
  field('created_at', graphQLDate)
]));
```

All GraphQL types are generic, in order to leverage Dart's strong typing support.

## Serialization

GraphQL types can `serialize` and `deserialize` input data. The exact implementation of this depends on the type.

```dart
var iso8601String = graphQLDate.serialize(DateTime.now());
var date = graphQLDate.deserialize(iso8601String);
print(date.millisecondsSinceEpoch);
```

## Validation

GraphQL types can `validate` input data.

```dart
var validation = myType.validate('@root', {...});

if (validation.successful) {
  doSomething(validation.value);
} else {
  print(validation.errors);
}
```

## Helpers

* `graphQLSchema` - Create a `GraphQLSchema`
* `objectType` - Create a `GraphQLObjectType` with fields
* `field` - Create a `GraphQLField` with a type/argument/resolver
* `listOf` - Create a `GraphQLListType` with the provided `innerType`
* `inputObjectType` - Creates a `GraphQLInputObjectType`
* `inputField` - Creates a field for a `GraphQLInputObjectType`

## Types

All of the GraphQL scalar types are built in, as well as a `Date` type:

* `graphQLString`
* `graphQLId`
* `graphQLBoolean`
* `graphQLInt`
* `graphQLFloat`
* `graphQLDate`

## Non-Nullable Types

You can easily make a type non-nullable by calling its `nonNullable` method.

## List Types

Support for list types is also included. Use the `listType` helper for convenience.

```dart
/// A non-nullable list of non-nullable integers
listOf(graphQLInt.nonNullable()).nonNullable();
```

### Input values and parameters

Take the following GraphQL query:

```graphql
{
   anime {
     characters(title: "Hunter x Hunter") {
        name
        age
     }
   }
}
```

And subsequently, its schema:

```graphql
type AnimeQuery {
  characters($title: String!): [Character!]
}

type Character {
  name: String
  age: Int
}
```

The field `characters` accepts a parameter, `title`. To reproduce this in `package:graphql_schema3`, use `GraphQLFieldInput`:

```dart
final GraphQLObjectType queryType = objectType('AnimeQuery', fields: [
  field('characters',
    listOf(characterType.nonNullable()),
    inputs: [
      new GraphQLFieldInput('title', graphQLString.nonNullable())
    ]
  ),
]);

final GraphQLObjectType characterType = objectType('Character', fields: [
  field('name', graphQLString),
  field('age', graphQLInt),
]);
```

In the majority of cases where you use GraphQL, you will be delegate the actual fetching of data to a database object, or some asynchronous resolver function.

`package:graphql_schema3` includes this functionality in the `resolve` property, which is passed a context object and a `Map<String, dynamic>` of arguments.

A hypothetical example of the above might be:

```dart
var field = field(
  'characters',
  graphQLString,
  resolve: (_, args) async {
    return await myDatabase.findCharacters(args['title']);
  },
);
```
