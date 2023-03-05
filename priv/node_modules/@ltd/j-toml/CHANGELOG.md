[English](https://GitHub.com/LongTengDao/j-toml/tree/master/CHANGELOG/English.md) | [简体中文](https://GitHub.com/LongTengDao/j-toml/tree/master/CHANGELOG/%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87.md)
___

1.  0.  0.  +   new feature: support TOML v1.0.0
            -   remove feature (experimental): `TOML.parse(,,,,xOptions?:{mix?,close?})`
    1.  0.  +   new feature (subsidiary): `TOML.parse(,,,,,sourcePath?:string)`
            -   remove feature (subsidiary): `{lineNumber,lineIndex}` on error thrown (since 0.5.*)
    2.  0.  *   change syntax (experimental): `TOML.parse(,,,,xOptions?:{tag?})`
    3.  0.  *   optimizing
    4.  0.  *   change feature (subsidiary): from `TOML.parse(,,,,,sourcePath?:string)` (since 1.1.0) to `TOML.parse(source:{path,data?})`
    5.  0.  *   optimizing
        1.  *   bug fix: `source.path` (since 1.4.0)
        2.  *   bug fix: check and forbid `02-29` for non-leap years (since 0.5.*)
            +   improve typing: detailing `.d.ts` for 4 types of date-time
    6.  0.  *   optimizing
    7.  0.  *   optimizing
    8.  0.  *   optimizing
    9.  0.  *   only run `require('fs')` when it's really used
            *   no more do `require('path').isAbsolute(source.path)` check
    10. 0.  *   update dependency `@ltd/j-orderify` (use `copyWithin` to optimize `ownKeys` `splice` instead of modifying `constructor[Symbol.species]`)
    11. 0.  *   change date-time internal implementation from private to symbol, to support `Proxy` use case
    12. 0.  *   compatibility: remove stage 3 class field syntax
            +   add ESM edition (with full tree shaking support)
        1.  *   fix typing file path
        2.  *   bug fix: fix ESM support of `package.json`
    13. 0.  *   reuse stage 4 class field syntax
            +   new feature: allow to skip the parameter `specificationVersion` (default to `1.0`)
            +   new feature: add `1.0`, `0.5`, `0.4`, `0.3`, `0.2`, `0.1` sub functions in `TOML.parse`
    14. 0.  *   fix indent in Markdown docs
    15. 0.  +   new feature: allow to omit the `multilineStringJoiner` parameter, as long as the final parsing does not actually encounter a multi-line string containing a newline to be preserved (not recommended)
    16. 0.  +   new feature: `TOML.stringify` method, and helpers `TOML.Section`, `TOML.inline`, `TOML.multiline`, `TOML.multiline.basic`, `TOML.literal`, `TOML.commentFor`
            +   new feature: export `TOML.OffsetDateTime`, `TOML.LocalDateTime`, `TOML.LocalDate`, `TOML.LocalTime` classes
            +   new feature (experimental): add `xOptions.comment`, to retain some comment information in the parsing result
            *   bug fix: fix no error thrown when parsing some kind of incorrect Offset Date-Time literal
            *   bug fix: fix parsing stack overflow caused by too much escaping in base string again (also preventive out of memory)
            *   bug fix: ensure that in 1.0 parsing mode, Tab after "line ending backslash" is handled correctly, while in 0.4 or previous modes, even space after "line ending backslash" should not work anymore
            *   bug fix: fix incorrect line number information in parsing error once met "line ending backslash"
            *   bug fix: fix parsing stack overflow caused by too many underscores in integer or float
            *   bug fix: fix the problem that `globalThis.require` doesn't exist actually
        1.  *   bug fix: make error position more exact
            *   bug fix: make `TOML.parse` more robust to eradicate broken by overlapped calling
    17. 0.  +   new feature: add parameter `source.require`, avoid statically loading `fs` module, etc. (to read TOML file data for specified `source.path`)
            +   new feature: add support to `Uint8Array` and `ArrayBuffer`
            +   new feature (experimental): add `xOptions.string`, to disable keys shaped like numbers, etc.
            +   new feature: quote keys shaped like number, etc., during `TOML.stringify`
    18. 0.  +   new feature: allow passing rest arguments of `TOML.parse` via an options object
    19. 0.  +   new feature: export helpers `TOML.isSection`, `TOML.isInline`
    20. 0.  +   new feature: add `UMD` format support to dist
    21. 0.  +   new feature: add `TOML.stringify` option to specify a integer range to serialize `number` type to TOML Integer
    22. 0.  *   the finalized `TOML.OffsetDateTime`, `TOML.LocalDateTime`, `TOML.LocalDate`, `TOML.LocalTime` class methods are officially launched in the document
            *   officially launch helpers `TOML.isSection`, `TOML.isInline` in the document
            *   bug fix: fix the issue when `TOML.inline` a table, the mutually-exclusive `TOML.Section` state is not removed
    23. 0.  *   based on TypeScript 4.5 new features `.d.mts` extension name and `types` category in `exports` field of `package.json`, provide own type declaration file `index.d.mts` for ESM mode of NPM edition
            *   compatibility: ensure when Node.js engine changes its internal implementation, the fast code could fall back to normal
            *   compatibility: remove lookbehind syntax in RegExp for Safari
    24. 0.  *   supplement the docs that the object style arguments of `TOML.parse` which was added since 1.18.0, also applies for the version sub functions of `TOML.parse`
            *   no longer error in 0.4 and previous version for whitespace after "line ending backslash" (revert the corresponding change in 1.16.0), no longer error in 0.5 and previous version for Tab literal in Basic String, no longer error in 0.5 and previous version for 1 or 2 quotation marks at the end of a multi-line string, because this library's support policy for previous versions of the TOML specification is consistent with the principle of not causing unnecessary errors
            *   no longer error in 0.2 and previous version for non-scalar values of `\u****` in Basic String
    25. 0.  *   the requirement in `.d.ts` for date-time value passed into `TOML.stringify` is relaxed to allow native `Date` (actual runtime behavior from the beginning)
            +   new feature: add `TOML.commentForThis` support for section table in stringify/parse
            *   change feature: no more silently trimming newlines in comments passed into `TOML.stringify`, but throw an error instead
            +   the requirement in `.d.ts` for array passed into `TOML.multiline` is relaxed to allow native empty array
            +   the requirement in `.d.ts` for value passed into `TOML.isInline` is relaxed to allow array
            +   new feature: helper `TOML.basic`
            *   change feature (experimental): the validity range of `TOML.parse`'s parameter `xOptions.exact` is enlarged
            *   change feature (experimental): `TOML.parse`'s parameter `xOptions` do not accept passing boolean or function as shorthand style anymore
            *   typing change: abandoned the unnecessary complexity of `.d.ts` about `TOML.parse`
            *   bug fix (experimental): fix the problem that `xOptions.exact` can not treat exponent part including underscore correctly
            +   new feature (experimental): `xOptions.literal`
            +   new feature: add value support for literal-related api
    26. 0.  *   bug fix: fix the error when `options.newline` of `TOML.stringify` is omitted (since 1.25.0)
            +   new feature: helper `TOML.multiline.array`
            *   more strict array of tables check in `TOML.stringify`
    27. 0.  *   compatibility: remove `??=` syntax for Node 14 compatibility
    28. 0.  +   new feature: helper `TOML.inline`'s second optional parameter to control space, and remember the writing style of single-line static array in `TOML.parse`
            *   bug fix: allow writing lowercase `t`, `z` in date-time for `TOML.parse`
    29. 0.  +   new feature: new `forceInlineArraySpacing` option in `TOML.stringify`
    30. 0.  +   new feature: new `options.T` option `'t'` support and `options.Z` option in `TOML.stringify`
    31. 0.  *   optimizing: `TOML.parse` Integer
            *   while `TOML.parse` is passed in `Buffer`, `Uint8Array` or `ArrayBuffer`, uniformly use `TextDecoder` instead of `buffer.toString()` or polyfill in non `Node.js` environment as `UTF-8` decoder
    32. 0.  *   feature perfecting: distinguish between `-NaN` and `NaN`
    33. 0.  *   more friendly error message for passing in array (usually come from `TOML.stringify` output without setting `options.newline`) to `TOML.parse`
            *   optimizing: avoid code point check twice for `Buffer`, `Uint8Array` or `ArrayBuffer` passing into `TOML.parse`
            *   optimizing: `TOML.stringify` for `-NaN`
        1.  *   bug fix: be compatible with the `NaN` implementation on some runtime environment (like old Edge browser) (since 1.32.0)
        2.  *   bug fix: correct leap year judging rule (since 1.5.2)
        3.  *   bug fix: leap second support of `TOML.OffsetDateTime` (since 0.5.*)
            *   bug fix: value of `TOML.OffsetDateTime` before 1970 (since 0.5.*)
    34. 0.  +   new feature: add `TOML.Keys` and `options.keys` for parsing, to avoid hash attack
            *   follow docs: not only get own properties of `options` object which passed into `TOML.parse` anymore (which is never said in the docs before)
            *   more friendly error message for `TOML.parse` arguments error
    35. 0.  *   optimizing: the internal implementation of `TOML.parse` `xOptions.tag` changed from array to linked list
        1.  *   fix typing file (since 1.34.0)
        2.  *   fix typing file (since 1.35.1)
        3.  *   bug fix: fix Offset Date-Time before 1970 without fractional seconds parsing crash (since 1.33.3)
            *   compatibility: remove `?.` and `??` syntax
            *   compatibility: remove `bigint` syntax (but using `TOML.parse` in environment without `BigInt` support, the related option must be set to `false`, otherwise, an error will be thrown)
    36. 0.  +   new feature: add non-`Object` `Symbol.toStringTag` for date-time implementation
    37. 0.  +   new feature: use different `Symbol.toStringTag` for the four types of date-time
    38. 0.  +   no longer error in 0.4 and previous version for positive or negative infinity, because they could be expressed by going out of range, and this library's support policy for previous versions of the TOML specification is consistent with the principle of not causing unnecessary errors
