# Change Log

## 3.2.1

### Changed
- `LICENSE` carries a copyright notice for the work done on this line, next to
  the upstream one it has always kept, as the BSD-3-Clause terms require.
  `AUTHORS.md` already recorded who did what; the licence file now says the same
  thing.
- The README says where to look for both, rather than describing the licence
  file as untouched.
- The README links each dependency to its pub.dev page. The pointer between
  these packages went to GitHub, which is the wrong destination from a pub.dev
  page.

No code changed.

## 3.2.0

First release published to pub.dev. The package was consumed straight from its
git repository until now.

### Fixed
- Validation refuses rather than raises. Every validator narrowed the parameter
  the base class declares `covariant` - an object type took a `Map`, a list type
  a `List`, a bounded scalar its own `T` - so a value of the wrong shape did not
  fail validation, it raised a `TypeError` from the call boundary. That is the
  one thing validation exists to prevent. All nine overrides take `Object?` now
  and answer a failed `ValidationResult`.

  The two shape checks that would have caught this were present but commented
  out, because with a `Map`-typed parameter they were unreachable. They are
  restored along with the widened parameter.
- The bounded scalars measured the raw input rather than the validated value,
  and their supertype accepts `null`, so `GraphQLNumMinType.validate(key, null)`
  crashed on the comparison. A null now passes the bound untouched: whether it
  is legal at all is the non-nullable wrapper's business, not the bound's.

### Added
- `example/main.dart`: builds a small schema by hand, then validates values
  against it, including the `Int` / `Float` coercion rule.
- Package metadata for pub.dev: a description that says what the package does
  rather than what to use instead, an issue tracker, and topics.
- 9 tests covering the above. 50 in all.

## 3.1.0

### Fixed
- Validating an unknown enum literal raised `Bad state: No element` instead of
  returning a failed `ValidationResult`. For a string-valued enum, built with
  `enumTypeFromStrings`, every literal took that path, so any client sending an
  unrecognised value crashed the resolver. Both `validate` and `convert` are
  affected.
- A field whose input has the wrong type raised a cast error while validating
  an object, rather than reporting the mismatch. `GraphQLType.convert` now
  answers `null` for a value of the wrong shape.
- `Float` rejected an integer literal. The specification coerces an integer to
  `Float`, and only in that direction, so `4` is now a valid `Float` while
  `4.2` remains an invalid `Int`.
- `GraphQLFieldInput.operator ==` compared `other.defaultValue` with itself, so
  two inputs differing only by their default value compared as equal.
- `GraphQLEnumType`, `GraphQLObjectType`, `GraphQLInputObjectType` and
  `GraphQLUnionType` hashed the identity of their field list while comparing
  its contents, so two equal instances could carry different hash codes. That
  breaks the `Object` contract and, with it, any `Set` or `Map` keyed on a type.
- `GraphQLObjectType.hashCode` and `GraphQLInputObjectType.hashCode` folded
  `name` in twice and never `description`.

### Removed
- The `quiver` dependency. Its `hash2` / `hash3` / `hash4` were the only thing
  used and `Object.hash` covers them.

### Added
- A test suite. There was none.

## 3.0.0

- Initial release