[English](https://GitHub.com/LongTengDao/j-toml/tree/master/docs/English/) | [简体中文](https://GitHub.com/LongTengDao/j-toml/tree/master/docs/%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87/)
___

`@ltd/j-toml` ![](https://img.shields.io/npm/dw/@ltd/j-toml "Downloads") ![](https://img.shields.io/npm/l/@ltd/j-toml "License") ![](https://img.shields.io/npm/v/@ltd/j-toml "Version") ![](https://img.shields.io/github/last-commit/LongTengDao/j-toml "Activity: GitHub last commit")
=============

`@ltd/j-toml` is an implementation of [TOML](https://TOML.io/) ("Tom's Obvious, Minimal Language") written by LongTengDao,  
which is the best config format he had ever seen.  
(Obviously for every people that tried to design a thing like that.)  

Node.js 14+
-----------

```shell
npm install @ltd/j-toml
```

```javascript
const TOML = require('@ltd/j-toml');// or: import * as TOML from '@ltd/j-toml';

const source         = `
      I_am_normal    = '...'
      hasOwnProperty = '...'
      constructor    = '...'
      __proto__      = '...'
`;

const rootTable = TOML.parse(source);

rootTable.I_am_normal    // '...'
rootTable.hasOwnProperty // '...'
rootTable.constructor    // '...'
rootTable.__proto__      // '...'
rootTable.valueOf        // undefined

Object.keys(rootTable)   // [ 'I_am_normal', 'hasOwnProperty', 'constructor', '__proto__' ]
```

`TOML.parse`
------------

```
TOML.parse(source[, options]);
```

```typescript
declare function parse (source :Source, options? :{
    joiner? :string,
    bigint? :boolean | number,
    x? :XOptions,
}) :Table;

type Source = string | ArrayBufferLike | Readonly<
    | { path :string, data :string | ArrayBufferLike, require? :NodeRequire }
    | { path :string,                                 require  :NodeRequire }
>;
type XOptions = object;
type Table = object;
```

### `arguments` (object style)

0.  #### `source`
    
    *   type: `string` / `ArrayBufferLike` / `Readonly<{ path :string, data :string | ArrayBufferLike, require? :NodeRequire }>` / `Readonly<{ path :string, require :NodeRequire }>`
    *   required
    
    You can pass in `string` or the UTF-8 encoding file original binary data `ArrayBufferLike` (`Buffer` / `Uint8Array` / `ArrayBuffer`) as the source content.  
    
    One difference is that when passing in `string`, parser will only check whether all characters are valid Unicode characters according to the specification (uncoupled UCS-4 character code is invalid);  
    When `ArrayBufferLike` is passed in, an additional check is made to see whether there is unknown code point (which has been automatically replaced by `U+FFFD` in the `string` state).  
    
    Another difference is that `ArrayBufferLike` can start with UTF BOM (`U+FEFF`), which is used for validation of file encoding (but it must be UTF-8 encoding, which is not a technical limit, but a specification requirement), and skipped before real parsing;  
    But `string` can't, because BOM belongs to UTF, not TOML.  
    
    If you want to be more console friendly when something of source content goes wrong, pass an object where the property `path` is the path of that `.toml` file, and the property `data` is the source content (`string` or `ArrayBufferLike`).  
    You can also omit the property `data`, the property `require` must be passed in at this time, because the `require('fs').readFileSync` interface needs to be used to read it.  
    Regardless of whether `data` is passed in, if `$ = require?.resolve?.paths?.('')?.[0]?.replace(/node_modules$/, '')` can be obtained, the absolute path will be obtained through `require('path').resolve($, source.path)`.  
    
1.  #### `options`
    
    An optional readonly object, the options it contains is as follows:  
    
    -   ##### `options.joiner`
        
        *   type: `string`
        *   optional
        
        For the multi-line basic strings and multi-line literal strings, what will be used to join the lines for parsing result.  
        Note: TOML always use `'\n'` or `'\r\n'` to split the document lines while parsing, which defined in TOML specification, **it has nothing to do with this parameter**, so don't be mixed up.  
        
        **If this parameter is not passed in**, the parsing process will throw an error where it is actually needed (a multi-line string containing a non-ignored newline):  
        
        ```toml
        error = """
        In this sample, the first and second newlines are ignored, \
        the third newline will trigger an error.
        """
        ```
        
    -   ##### `options.bigint`
        
        *   type: `boolean` / `number`
        *   default: `true`
        
        Specify whether you want or not to use `BigInt` for integer type value. A `number` type argument allows you to control it by a max limit, like `Number.MAX_SAFE_INTEGER` (and the min limit from `-options.bigint`, if `options.bigint>=0`; otherwise as the min limit, and the max limit is `-options.bigint-1`).  
        
    -   ##### `options.keys`
        
        *   type: `TOML.Keys` / `null`
        *   default: `null`
        
        Safe list for keys, to avoid hash attack. Constructing by passing an array of strings into `TOML.Keys`.  
        
    -   ##### `options.x`
        
        The extensional features not in the specification.  
        Include keeping the key/value pairs order of tables, integers larger than `signed long`, multi-line inline table with trailing comma even no comma, `null` value, custom constructor, etc.  
        They are private experimental discouraged features.  
        See [xOptions](https://GitHub.com/LongTengDao/j-toml/blob/master/docs/English/xOptions.md).  

### `arguments` (traditional style)

0.  #### `source`
    
    See `source` in "object style" above.  
    
1.  #### `specificationVersion`
    
    *   type: `1.0` / `0.5` / `0.4` / `0.3` / `0.2` / `0.1`
    *   default: `1.0`
    *   deprecated: use `TOML.parse[specificationVersion]` instead would be better
    
    Note: if you skip this argument, the rest arguments must be moved one position to the left.  
    
2.  #### `multilineStringJoiner`
    
    See `options.joiner` in "object style" above.  
    
3.  #### `useBigInt`
    
    See `options.bigint` in "object style" above.  
    
4.  #### `xOptions`
    
    See `options.x` in "object style" above.  

### `return`

*   type: `Table`

Return the root table (tables parsed by this implementation are objects without any extended properties).  

Note: the requirements of 4 types TOML date-time do not fully correspond to the native `Date` type, they are implemented by this library on the basis of `Date`, see the `.d.ts` file (`OffsetDateTime`, `LocalDateTime`, `LocalDate`, `LocalTime`, and `OffsetDateTime` provides fractional second support with unlimited precision) for details.  

### `throw`

*   type: `Error`

There will be an error thrown, when the arguments not meet the requirement or there is any error within the source. Parsing during parsing caused by hacking arguments will also be blocked.  

This library will not cause stack overflow error unexpectedly due to too deep tables or arrays, or too many escaping in basic string, or too many underscores in integer or float.  

`TOML.parse[1.0]` `TOML.parse[0.5]` `TOML.parse[0.4]` `TOML.parse[0.3]` `TOML.parse[0.2]` `TOML.parse[0.1]`
-----------------------------------------------------------------------------------------------------------

This library's support policy for previous versions of the TOML specification is under the principle of not causing unnecessary errors.  
For example, although `""""Hi!""""` is not supported until 1.0, but in 0.5 you can get the same value via `'"Hi!"'`, so there won't be an error thrown;  
`nan` can really not be expressed until 0.5, so in order to avoid unexpected behavior that a 0.4-compliant downstream program has not considered, the parser behaves version-dependent.  

So, if there is no specific reason (e.g. the downstream program could not deal with `NaN`, fractional seconds and edge date-time values, Local Date-Time / Local Date / Local Time types, empty string key name, mixed type array even array of tables / table under array of arrays structure yet), the latest version is recommended.  

### `arguments` (object style)

0.  #### `source`
    
    Vide `TOML.parse` above.  
    
1.  #### `options`
    
    Vide `TOML.parse` above.  

### `arguments` (traditional style)

0.  #### `source`
    
    Vide `TOML.parse` above.  
    
1.  #### `multilineStringJoiner`
    
    Vide `TOML.parse` above.  
    
2.  #### `useBigInt`
    
    Vide `TOML.parse` above.  
    
3.  #### `xOptions`
    
    Vide `TOML.parse` above.  

### `return`

Vide `TOML.parse` above.  

### `throw`

Vide `TOML.parse` above.  

`TOML.stringify`
----------------

```
TOML.stringify(rootTable[, options]);
```

```typescript
declare function stringify (rootTable :ReadonlyTable, options? :Readonly<{
    integer? :number,
    newline? :'\n' | '\r\n',
    newlineAround? :'document' | 'section' | 'header' | 'pairs' | 'pair',
    indent? :string | number,
    T? :'T' | 't' | ' ',
    Z? :'Z' | 'z',
    xNull? :boolean,
    xBeforeNewlineInMultilineTable? :',' | '',
    forceInlineArraySpacing? :0 | 1 | 2 | 3,
}>) :string | string[];
```

### `arguments`

0.  #### `rootTable`
    
    *   type: `ReadonlyTable`
    *   required
    
    A readonly object, its own string keys can only contain valid TOML types.  
    
1.  #### `options`
    
    An optional readonly object, the options it contains is as follows:  
    
    -   ##### `options.integer`
        
        *   type: `number`
        *   optional
        
        Specify a range, then the integer `number` type value in that will be serialized to TOML Integer. This argument allows you to control the max limit exactly, like `Number.MAX_SAFE_INTEGER` (and the min limit from `-options.integer`, if `options.integer>=0`; otherwise as the min limit, and the max limit is `-options.integer-1`).  
        
    -   ##### `options.newline`
        
        *   type: `'\n'` / `'\r\n'`
        *   optional
        
        What to use as the newline for serialization. **If this parameter is not specified**, the function will return an array of strings (representing each line) instead of a whole string.  
        
    -   ##### `options.newlineAround`
        
        *   type: `'document'` / `'section'` / `'header'` / `'pairs'` / `'pair'`
        *   default: `'header'`
        
        While serializing, where to insert empty lines to improve readability.  
        
        1.  `'document'`: only make sure the document begins and ends with a empty line for git diff (if the document is empty, only one empty line will be kept);
        2.  `'section'`: further ensures that sections (block tables) are separated by an empty line;
        3.  `'header'`: further ensure that each block table's header and its key/value pairs are separated by an empty line;
        4.  `'pairs'`: further ensure that the own key/value pairs of each block table are separated by an empty lines (while the dotted keys are grouped together);
        5.  `'pair'`: further ensure that all key/value pairs (including dotted keys) of each block table, are separated by an empty lines.
        
        Of these, `'section'` and `'header'` are generally the best modes in practice, the former being more suitable for simple cases where sections don't contain each other, while the latter is friendly to both simple and nested (and therefore it's the default mode).  
        
    -   ##### `options.indent`
        
        *   type: `string` / `number`
        *   default: `'\t'`
        
        How to indent items in a static array which is in multi-line mode.  
        
        A string value represents the characters used for indentation (characters other than Tab or space are invalid), while a numeric value represents the number of spaces used.  
        
        Note: this library does not indent key/value pairs of block tables, because getting rid of indentation is the primary value of TOML's existence.  
        
    -   ##### `options.T`
        
        *   type: `'T'` / `'t'` / `' '`
        *   default: `'T'`
        
        The delimiter between date and time.  
        
    -   ##### `options.Z`
        
        *   type: `'Z'` / `'z'`
        *   default: `'Z'`
        
        How to represent offset `Z`.  
        
    -   ##### `options.preferCommentFor`
        
        *   type: `'key'` / `'this'`
        *   default: `'key'`

        See **comment** part below.  
        
    -   ##### `options.xNull`
        
        *   type: `boolean`
        *   default: `false`
        
        Whether `null` values are allowed to be serialized (to `null`).  
        
        If this option is not enabled, there will be an error thrown when a `null` value is found, just like any other type that cannot be serialized, because it's not allowed in the current version specification.  
        
    -   ##### `options.xBeforeNewlineInMultilineTable`
        
        *   type: `','` / `''`
        *   optional
        
        For inline tables marked multi-line mode, whether to use a comma before the newline.  
        
        Note that this is not valid in the current version specification, so if this option is not explicitly specified, the incoming inline table will be serialized in single-line mode even if it is marked as multi-line mode.  
        
    -   ##### `options.forceInlineArraySpacing`
        
        *   type: `0` / `1` / `2` / `3`
        *   optional
        
        Regardless of the original writing style of each single-line static array, serialize in the specified mode.  
        
        |     | empty | non-empty     |
        |:---:|:-----:|:-------------:|
        | `0` | `[]`  | `[0, 1, 2]`   |
        | `1` | `[ ]` | `[0, 1, 2]`   |
        | `2` | `[]`  | `[ 0, 1, 2 ]` |
        | `3` | `[ ]` | `[ 0, 1, 2 ]` |

### `return`

*   type: `string` / `string[]`

Returns a TOML document string, or an array of line-by-line strings. This depends on whether `option.newline` is specified.  

### `throw`

*   type: `Error`

An error is thrown if the options does not meet the requirements, or there is an unsupported value type in the input data, or the result size exceeds limit.  

This library will not cause stack overflow error unexpectedly due to too deep tables or arrays.  

`TOML.Section` `TOML.inline` `TOML.multiline` `TOML.multiline.array` `TOML.multiline.basic` `TOML.basic` `TOML.literal` `TOML.commentFor` `TOML.commentForThis` `TOML.isSection` `TOML.isInline`
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Due to the flexibility of TOML syntax, which greatly meeting the needs of reading and writing directly, there had been great difficulty for serialization solution.  

This library provides several helper functions to try to terminate this trouble.  

---

Let's start with **table** and **array**.  

Considering how JS code is read and written, **the default mode for this library to treat unmarked tables is dotted key/value pairs** (unless the table is empty or at somewhere such operation is impossible, in which cases it will be serialized in inline mode automatically).  
You can use the `Section` function to mark a table as a block table (and return the input table), or use the `inline` function to mark the table as an inline table (return the input table as well).  
You can also use `multiline` function to mark a table as a multiline mode inline table (and return it), but note that this is not the specification allowed currently (remember to specify `options.xBeforeNewlineInMultilineTable` to make such marking will not be ignored when serializing).  

```javascript
stringify({
    key: 'value',
    dotted: {
        key: 'value',
    },
    inlineTable: inline({ key: 'value' }),
    mix: {
        key: 'value',
        table: Section({
            key: 'value',
        }),
    },
    table: Section({
        key: 'value',
        table: Section({
            key: 'value',
        }),
    }),
});
```

```toml

key = 'value'
dotted.key = 'value'
inlineTable = { key = 'value' }
mix.key = 'value'

[mix.table]

key = 'value'

[table]

key = 'value'

[table.table]

key = 'value'

```

A non-empty array, whose items are tables that marked by `Section`, will be serialized as "array of tables". Note that an array's items must all be or all not be tables marked by `Section`.  
Otherwise, **arrays are treated as static and multi-line by default**. If you want single-line mode, you can use the `inline` function to mark it (and `multiline.array` to reverse).  
`inline`'s second parameter can give you more abilities to control serializing spaces. `2` means putting spaces between two sides brackets and items, `1` means an empty array should include a space, `3` means both enabled, `0` means both disabled. The default mode is `3`. This will be ignored when `options.forceInlineArraySpacing` is enabled.  

This default behavior is different with most implementation libraries and a little more cumbersome (in most cases, people expect an objects array to be serialized as an "array of tables" by default).  
The central reason for this design is, considering how JS code is read and written, "array of table" rather than static array should look marked in code, and its item should better look the same as the section table.  

```javascript
stringify({
    staticArray: [
        'string',
        { },
    ],
    staticArray_singleline: inline([ 1.0, 2n ]),
    arrayOfTables: [
        Section({
        }),
    ],
});
```

```toml

staticArray = [
    'string',
    { },
]
staticArray_singleline = [ 1.0, 2 ]

[[arrayOfTables]]

```

Data from `parse` of this library retains the memory of the writing style above, which means there is no need to manually mark them again when re-serialize the modified data.  
You can transparently tell what style the table from `parse` is written in by `isSection` and `isInline`.  

---

Another sore point is **comment**. Obviously we don't want a configuration file that contains comments lose all comment information after being modified by programs.  
However, comments are comments in nature, so this feature is turned off in `parse` by default, you need to explicitly enable this via `xOptions.comment`.  

For brand-new data, you can write `[commentFor(key)]` explicitly as key in your tables (this gives you a `symbol` as key, and the value should be the comment content string, `parse` preserves comments basing on the same mechanism), so that the comment is after the value belong the `key` in the final serialization! (Note that the comment value can not include any newline, or there will be an error thrown.)  

```javascript
stringify({
    
    key: 'value', [commentFor('key')]: ' this is a key/value pair',
    dotted: {
        key: 'value', [commentFor('key')]: ' this is a dotted key/value pair',
    },
    
    [commentFor('table')]: ' this is a table header',
    table: Section({ [commentForThis]: 'you can also write table header comment inside',
    }),
    // when two writing styles both exist but their values are different, the result depends on `options.preferCommentFor`
    
    tables: [
        Section({ [commentForThis]: ' this is a table header in array of tables',
        }),
    ],
    
});
```

```toml

key = 'value' # this is a key/value pair
dotted.key = 'value' # this is a dotted key/value pair

[table] # this is a table header

[[tables]] # this is a table header in array of tables

```

---

There still left **string**, **integer** and **float**. Their writing choices, just as gymnastics scoring points, has no perfect solution to be specified (without solving problem by creating more); and they are atom values, no good way to preserve their preferences in the data producted by `parse`.  
This library provides several helper functions for this purpose, including `literal`, `multiline` (string case), `multiline.basic` and `basic` (which enforce the use of (multi-line) basic string rather than the (multi-line) literal string tried in preference).  

When you need to serialize a brand-new temporary data directly, use `literal` to specify the writing style:  

```javascript
stringify({
    underscore: literal`1_000`,
    zero: literal`10.00`,
    base: literal`0o777`,
    mark: inline([ '+10e10', '+inf' ].map(literal)),
    multilineString: literal`"""
1\b2
3"""`,
});
```

```toml

underscore = 1_000
zero = 10.00
base = 0o777
mark = [ +10e10, +inf ]
multilineString = """
1\b2
3"""

```

Here, `multiline` (string case) would help when the multi-line string comes from a variable (e.g., data from `parse`):  

```toml

base = 0o777
multilineString = """
1\b2
3"""

```

```javascript
const table = TOML.parse(source, { joiner: '\n' });

table.base = TOML.literal('0o' + table.base.toString(8).padStart(3, '0'));
table.multilineString = TOML.multiline(table.multilineString + '\b4');

TOML.stringify(table);
```

```toml

base = 0o777
multilineString = """
1\b2
3\b4"""

```

By default, `multiline` (string case) splits the input string with `'\n'`, for example `'1\b2\n3\b4'` will be treated as `[ '1\b2 ', '3\b4' ]`.  
But if your requirements are very tricky, such as if your data is parsed by `TOML.parse(source, { joiner: '\b' })`, you can directly the split string array `'1\b2\n3\b4'.split('\b')` (viz `[ '1', '2\n3', '4' ]`), the final serialization result will be:  

```toml
multilineString = """
1
2\n3
4"""
```

`multiline.basic` can force a multi-line basic string to be generated, even if the actual value could be directly represented by a multi-line literal string.  
Similarly, `basic` can force a (single-line) basic string to be generated, even if the actual value could be directly represented by a (single-line) literal string.  

Note that `literal` or `multiline` (string case) or `multiline.basic` or `basic` does not return an atomic value (`string`, `number`, `bigint`), but a placeholder object recording serialization information (`object`).  
When conditions are met (see the `.d.ts` file for details; in simple terms, when the value is clear), the object type corresponds to the atomic type (`String`, `Number`, `BigInt`), so that it can satisfy common operational requirements in addition to `stringify`.  
When `parse`, you need to enable the `xOptions.literal`, to preserve atomic value writing style information based on the same mechanism, so that when `stringify` back, writing preferences will be preserved as much as possible.  
