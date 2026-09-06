# Change Log

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