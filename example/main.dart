import 'package:graphql_schema3/graphql_schema3.dart';

/// Builds a small schema by hand, then validates a value against it.
void main() {
  final status = enumTypeFromStrings('Status', <String>['active', 'closed']);

  final user = objectType(
    'User',
    fields: <GraphQLObjectField<dynamic, dynamic>>[
      field('name', graphQLString.nonNullable()),
      field('age', graphQLInt),
      field('status', status),
    ],
  );

  final schema = graphQLSchema(
    queryType: objectType(
      'Query',
      fields: <GraphQLObjectField<dynamic, dynamic>>[
        field('user', user, resolve: (_, _) => <String, dynamic>{}),
      ],
    ),
  );

  print(schema.queryType!.name); // Query

  // Validation reports what is wrong rather than throwing.
  final ok = user.validate('user', <String, dynamic>{
    'name': 'anna',
    'age': 30,
    'status': 'active',
  });
  print('valid: ${ok.successful}'); // true

  final bad = user.validate('user', <String, dynamic>{
    'name': 'anna',
    'status': 'archived',
  });
  print('valid: ${bad.successful}'); // false
  print(bad.errors);

  // Int does not accept a double, Float does accept an int: the specification
  // coerces in that direction only.
  print(graphQLFloat.validate('n', 4).successful); // true
  print(graphQLInt.validate('n', 4.2).successful); // false
}
