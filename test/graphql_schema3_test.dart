import 'package:graphql_schema3/graphql_schema3.dart';
import 'package:test/test.dart';

void main() {
  group('scalars', () {
    test('string accepts a string and rejects anything else', () {
      expect(graphQLString.validate('field', 'hello').successful, isTrue);
      expect(graphQLString.validate('field', 42).successful, isFalse);
      expect(graphQLString.serialize('hello'), 'hello');
      expect(graphQLString.deserialize('hello'), 'hello');
    });

    test('int accepts an integer and rejects a double', () {
      expect(graphQLInt.validate('field', 42).successful, isTrue);
      expect(graphQLInt.validate('field', 4.2).successful, isFalse);
      expect(graphQLInt.validate('field', 'x').successful, isFalse);
    });

    test('float accepts both an integer and a double', () {
      expect(graphQLFloat.validate('field', 4.2).successful, isTrue);
      expect(graphQLFloat.validate('field', 4).successful, isTrue);
    });

    test('boolean accepts a bool only', () {
      expect(graphQLBoolean.validate('field', true).successful, isTrue);
      expect(graphQLBoolean.validate('field', 'true').successful, isFalse);
    });

    test('date round-trips through its serialized form', () {
      final DateTime value = DateTime.utc(2026, 5, 21, 14, 30);
      final String serialized = graphQLDate.serialize(value);
      expect(graphQLDate.deserialize(serialized), value);
      expect(graphQLDate.validate('field', serialized).successful, isTrue);
      expect(graphQLDate.validate('field', 'not a date').successful, isFalse);
    });

    test('constrained scalars enforce their bound', () {
      expect(graphQLPositiveInt.validate('field', 1).successful, isTrue);
      expect(graphQLPositiveInt.validate('field', 0).successful, isFalse);
      expect(graphQLNonNegativeInt.validate('field', 0).successful, isTrue);
      expect(graphQLNegativeInt.validate('field', -1).successful, isTrue);
      expect(graphQLNegativeInt.validate('field', 0).successful, isFalse);
    });

    test('non-empty string rejects the empty string', () {
      expect(graphQLNonEmptyString.validate('field', 'a').successful, isTrue);
      expect(graphQLNonEmptyString.validate('field', '').successful, isFalse);
    });

    test('a failed validation carries an error mentioning the key', () {
      final ValidationResult<String> result = graphQLString.validate(
        'userName',
        7,
      );
      expect(result.successful, isFalse);
      expect(result.errors, isNotEmpty);
      expect(result.errors.first, contains('userName'));
    });
  });

  group('list type', () {
    test('validates every item and collects the failures', () {
      final GraphQLListType<String, String> type = listOf(graphQLString);

      expect(type.validate('field', <String>['a', 'b']).successful, isTrue);

      final ValidationResult<List<String>> failed = type.validate(
        'field',
        <Object>['a', 7],
      );
      expect(failed.successful, isFalse);
      expect(failed.errors, hasLength(1));
      expect(failed.errors.first, contains('index 1'));
    });

    test('serializes and deserializes through its inner type', () {
      final GraphQLListType<DateTime, String> type = listOf(graphQLDate);
      final List<DateTime> value = <DateTime>[
        DateTime.utc(2026),
        DateTime.utc(2027),
      ];
      expect(type.deserialize(type.serialize(value)), value);
    });

    test('prints as the GraphQL list notation', () {
      expect(listOf(graphQLString).toString(), '[String]');
    });
  });

  group('non-nullable type', () {
    test('rejects null and delegates everything else', () {
      final GraphQLType<String, String> type = graphQLString.nonNullable();
      expect(type.validate('field', null).successful, isFalse);
      expect(type.validate('field', 'a').successful, isTrue);
    });

    test('accepts a List<dynamic> for a non-nullable list', () {
      // A decoded JSON body always hands over List<dynamic>, never the reified
      // List<String> the type argument names.
      final GraphQLType<List<String>, List<String>> type = listOf(
        graphQLString,
      ).nonNullable();
      final List<dynamic> input = <dynamic>['a', 'b'];
      expect(type.validate('field', input).successful, isTrue);
    });

    test('refuses to be made non-nullable twice', () {
      expect(
        () => graphQLString.nonNullable().nonNullable(),
        throwsUnsupportedError,
      );
    });

    test('prints with a trailing bang', () {
      expect(graphQLString.nonNullable().toString(), 'String!');
    });
  });

  group('enum type', () {
    test('accepts a declared name and rejects an unknown one', () {
      final GraphQLEnumType<String> type = enumTypeFromStrings(
        'Colour',
        <String>['red', 'green'],
      );
      expect(type.validate('field', 'red').successful, isTrue);
      expect(type.validate('field', 'blue').successful, isFalse);
      expect(type.validate('field', 'blue').errors.first, contains('Colour'));
    });

    test('maps names onto their Dart values', () {
      final GraphQLEnumType<dynamic> type = enumType<int>(
        'Level',
        <String, int>{'low': 1, 'high': 2},
      );
      expect(type.values.map((GraphQLEnumValue<dynamic> v) => v.name), <String>[
        'low',
        'high',
      ]);
      expect(type.values.map((GraphQLEnumValue<dynamic> v) => v.value), <int>[
        1,
        2,
      ]);
    });
  });

  group('object type', () {
    GraphQLObjectType user() => objectType(
      'User',
      fields: <GraphQLObjectField<dynamic, dynamic>>[
        field('name', graphQLString, resolve: (_, _) => 'anna'),
        field('age', graphQLInt, resolve: (_, _) => 30),
      ],
    );

    test('validates an input map against its fields', () {
      final GraphQLObjectType type = user();
      expect(
        type.validate('user', <String, Object>{
          'name': 'anna',
          'age': 30,
        }).successful,
        isTrue,
      );
      expect(
        type.validate('user', <String, Object>{
          'name': 7,
          'age': 30,
        }).successful,
        isFalse,
      );
    });

    test('rejects a field the type does not declare', () {
      expect(
        user().validate('user', <String, Object>{'nickname': 'a'}).successful,
        isFalse,
      );
    });

    test('inherits the fields of an interface', () {
      final GraphQLObjectType node = objectType(
        'Node',
        isInterface: true,
        fields: <GraphQLObjectField<dynamic, dynamic>>[
          field('id', graphQLString, resolve: (_, _) => '1'),
        ],
      );
      final GraphQLObjectType post = objectType(
        'Post',
        fields: <GraphQLObjectField<dynamic, dynamic>>[
          field('title', graphQLString, resolve: (_, _) => 't'),
        ],
        interfaces: <GraphQLObjectType>[node],
      );

      expect(post.interfaces, contains(node));
      expect(node.possibleTypes, contains(post));
    });
  });

  group('equality and hashCode', () {
    test('two identical field inputs agree', () {
      final GraphQLFieldInput<String, String> a =
          GraphQLFieldInput<String, String>('id', graphQLString);
      final GraphQLFieldInput<String, String> b =
          GraphQLFieldInput<String, String>('id', graphQLString);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('a field input differing by name is not equal', () {
      expect(
        GraphQLFieldInput<String, String>('id', graphQLString),
        isNot(
          equals(GraphQLFieldInput<String, String>('other', graphQLString)),
        ),
      );
    });

    test('a field input differing by default value is not equal', () {
      expect(
        GraphQLFieldInput<String, String>(
          'id',
          graphQLString,
          defaultValue: 'a',
        ),
        isNot(
          equals(
            GraphQLFieldInput<String, String>(
              'id',
              graphQLString,
              defaultValue: 'b',
            ),
          ),
        ),
      );
    });

    test('two identical object fields agree', () {
      final GraphQLObjectField<String, String> a = field(
        'name',
        graphQLString,
        resolve: null,
      );
      final GraphQLObjectField<String, String> b = field(
        'name',
        graphQLString,
        resolve: null,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('an object field differing by deprecation is not equal', () {
      expect(
        field<String, String>('name', graphQLString, resolve: null),
        isNot(
          equals(
            field<String, String>(
              'name',
              graphQLString,
              resolve: null,
              deprecationReason: 'gone',
            ),
          ),
        ),
      );
    });

    test('two identical enum types agree', () {
      final GraphQLEnumType<String> a = enumTypeFromStrings('Colour', <String>[
        'red',
      ]);
      final GraphQLEnumType<String> b = enumTypeFromStrings('Colour', <String>[
        'red',
      ]);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('an enum type differing by its values is not equal', () {
      expect(
        enumTypeFromStrings('Colour', <String>['red']),
        isNot(equals(enumTypeFromStrings('Colour', <String>['red', 'green']))),
      );
    });

    test('two identical enum values agree', () {
      final GraphQLEnumValue<int> a = GraphQLEnumValue<int>('low', 1);
      final GraphQLEnumValue<int> b = GraphQLEnumValue<int>('low', 1);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two identical object types agree', () {
      GraphQLObjectType build() => objectType(
        'User',
        fields: <GraphQLObjectField<dynamic, dynamic>>[
          field('name', graphQLString, resolve: null),
        ],
      );

      expect(build(), equals(build()));
      expect(build().hashCode, equals(build().hashCode));
    });

    test('an object type differing by name is not equal', () {
      expect(objectType('A'), isNot(equals(objectType('B'))));
    });

    test('list and non-nullable wrappers compare by their inner type', () {
      expect(listOf(graphQLString), equals(listOf(graphQLString)));
      expect(listOf(graphQLString), isNot(equals(listOf(graphQLInt))));
      expect(graphQLString.nonNullable(), equals(graphQLString.nonNullable()));
    });
  });

  group('exceptions', () {
    test('a message-only exception serializes to the GraphQL error shape', () {
      final GraphQLException exception = GraphQLException.fromMessage('boom');
      final Map<String, List<Map<String, dynamic>>> json = exception.toJson();

      expect(json['errors'], hasLength(1));
      expect(json['errors']!.first['message'], 'boom');
      expect(json['errors']!.first.containsKey('locations'), isFalse);
    });

    test('an error with a location reports line and column', () {
      final GraphQLExceptionError error = GraphQLExceptionError(
        'boom',
        locations: <GraphExceptionErrorLocation>[
          GraphExceptionErrorLocation(3, 7),
        ],
      );

      expect(error.toJson()['locations'], <Map<String, int>>[
        <String, int>{'line': 3, 'column': 7},
      ]);
    });
  });

  group('schema', () {
    test('holds the operation types it was given', () {
      final GraphQLObjectType query = objectType('Query');
      final GraphQLObjectType mutation = objectType('Mutation');
      final GraphQLSchema schema = graphQLSchema(
        queryType: query,
        mutationType: mutation,
      );

      expect(schema.queryType, same(query));
      expect(schema.mutationType, same(mutation));
      expect(schema.subscriptionType, isNull);
    });
  });

  group('regressions', () {
    test('an unknown enum literal fails instead of raising', () {
      final GraphQLEnumType<String> type = enumTypeFromStrings(
        'Colour',
        <String>['red'],
      );

      expect(() => type.validate('field', 'blue'), returnsNormally);
      expect(type.validate('field', 'blue').successful, isFalse);
      expect(type.convert('blue'), 'blue');
      expect(type.convert(const Object()), isNull);
    });

    test('a mistyped object field fails instead of raising', () {
      final GraphQLObjectType type = objectType(
        'User',
        fields: <GraphQLObjectField<dynamic, dynamic>>[
          field('name', graphQLString, resolve: null),
        ],
      );

      expect(
        () => type.validate('user', <String, Object>{'name': 7}),
        returnsNormally,
      );
      expect(
        type.validate('user', <String, Object>{'name': 7}).successful,
        isFalse,
      );
    });

    test('convert answers null rather than raising on the wrong shape', () {
      expect(graphQLString.convert(7), isNull);
      expect(graphQLString.convert('a'), 'a');
    });

    test('a self-referencing type can be hashed', () {
      // A GraphQL schema is routinely recursive: a User has friends who are
      // Users. Hashing must terminate all the same.
      final GraphQLObjectType user = objectType('User');
      user.fields.add(field('friend', user, resolve: null));

      expect(() => user.hashCode, returnsNormally);
      expect(() => <GraphQLObjectType>{user}, returnsNormally);
    });

    test('a type cycling through a list can be hashed', () {
      final GraphQLObjectType node = objectType('Node');
      node.fields.add(field('children', listOf(node), resolve: null));

      expect(() => node.hashCode, returnsNormally);
    });

    test('a union hashes on the contents of its member list', () {
      GraphQLUnionType build() => GraphQLUnionType('Shape', <GraphQLObjectType>[
        objectType('Circle'),
        objectType('Square'),
      ]);

      expect(build(), equals(build()));
      expect(build().hashCode, equals(build().hashCode));
    });

    test('an input object hashes on the contents of its field list', () {
      GraphQLInputObjectType build() => objectType(
        'User',
        fields: <GraphQLObjectField<dynamic, dynamic>>[
          field('name', graphQLString, resolve: null),
        ],
      ).toInputObject('UserInput');

      expect(build(), equals(build()));
      expect(build().hashCode, equals(build().hashCode));
    });
  });

  // Every validator used to narrow its parameter - an object type took a `Map`,
  // a list type a `List`, a bounded scalar its own `T` - while the base declares
  // the parameter `covariant`. So a value of the wrong shape did not fail
  // validation, it raised a TypeError from the call boundary, which is the one
  // thing validation exists to avoid. The bounded scalars also measured the raw
  // input, and their supertype accepts null, so a null crashed the comparison.
  group('validation refuses rather than raises', () {
    final GraphQLObjectType user = objectType(
      'User',
      fields: <GraphQLObjectField<dynamic, dynamic>>[
        field('name', graphQLString, resolve: null),
      ],
    );

    test('an object type answers a failure for a non-map', () {
      final ValidationResult<Map<String, dynamic>> result = user.validate(
        'user',
        'not a map',
      );

      expect(result.successful, isFalse);
      expect(result.errors.single, contains('to be a Map'));
    });

    test('an object type answers a failure for null', () {
      expect(user.validate('user', null).successful, isFalse);
    });

    test('a list type answers a failure for a non-list', () {
      final ValidationResult<List<String>> result = listOf(
        graphQLString,
      ).validate('tags', 'not a list');

      expect(result.successful, isFalse);
      expect(result.errors.single, contains('to be a list'));
    });

    test('a list type answers a failure for null', () {
      expect(listOf(graphQLString).validate('tags', null).successful, isFalse);
    });

    test('a bounded number answers a failure for a string', () {
      expect(
        GraphQLNumMinType<int>('Int', 3).validate('n', 'nope').successful,
        isFalse,
      );
    });

    test('a bounded number still enforces its bound', () {
      expect(
        GraphQLNumMinType<int>('Int', 3).validate('n', 2).successful,
        isFalse,
      );
      expect(
        GraphQLNumMinType<int>('Int', 3).validate('n', 4).successful,
        isTrue,
      );
      expect(
        GraphQLNumMaxType<int>('Int', 3).validate('n', 4).successful,
        isFalse,
      );
      expect(
        GraphQLNumRangedType<int>('Int', 2, 4).validate('n', 3).successful,
        isTrue,
      );
      expect(
        GraphQLNumRangedType<int>('Int', 2, 4).validate('n', 5).successful,
        isFalse,
      );
    });

    test('a bounded number lets a null through to the nullability rules', () {
      // The bound has nothing to measure; whether null is legal at all is the
      // non-nullable wrapper's business, not the bound's.
      expect(
        GraphQLNumMinType<int>('Int', 3).validate('n', null).successful,
        isTrue,
      );
    });

    test('a bounded string answers a failure for a number', () {
      expect(graphQLStringMin(3).validate('s', 42).successful, isFalse);
    });

    test('a bounded string still enforces its bound', () {
      expect(graphQLStringMin(3).validate('s', 'ab').successful, isFalse);
      expect(graphQLStringMin(3).validate('s', 'abc').successful, isTrue);
      expect(graphQLStringMax(3).validate('s', 'abcd').successful, isFalse);
      expect(graphQLStringRange(2, 4).validate('s', 'abc').successful, isTrue);
      expect(
        graphQLStringRange(2, 4).validate('s', 'abcde').successful,
        isFalse,
      );
    });
  });
}
