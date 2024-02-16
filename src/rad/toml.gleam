//// [TOML](https://toml.io/) is a markup language used by the `gleam` build
//// tool and `rad` for configuration and recordkeeping.
////
//// Every Gleam project at a minimum has its own `gleam.toml` config, which
//// both `gleam` and `rad` can read from and work with.
////

import gleam/dynamic.{
  type DecodeError, type DecodeErrors, type Decoder, type Dynamic,
}
import gleam/list
import gleam/result
import gleam/string
import snag.{type Snag}
@target(erlang)
import gleam/dict
@target(erlang)
import gleam/function

/// A TOML [table](https://toml.io/en/v1.0.0#table) of dynamic data.
///
pub type Toml

/// Results in typed Gleam data decoded from the given [`Toml`](#Toml)'s
/// `key_path` on success, or a [`Snag`](https://hexdocs.pm/snag/snag.html#Snag)
/// on failure.
///
pub fn decode(
  from toml: Toml,
  get key_path: List(String),
  expect decoder: Decoder(a),
) -> Result(a, Snag) {
  use item <- result.try(
    toml
    |> do_toml_get(key_path)
    |> result.map_error(with: fn(_nil) {
      path_message("failed to find item `", key_path, "`")
      |> snag.new
    }),
  )

  item
  |> decoder
  |> result.map_error(with: decode_errors_to_snag(_, key_path))
}

@external(erlang, "rad_ffi", "toml_get")
@external(javascript, "../rad_ffi.mjs", "toml_get")
fn do_toml_get(toml: Toml, key_path: List(String)) -> Result(Dynamic, Nil)

/// Results in a list of every key-value pair for which the value can be
/// successfully decoded from the given [`Toml`](#Toml)'s `key_path` using the
/// given
/// [`Decoder`](https://hexdocs.pm/gleam_stdlib/gleam/dynamic.html#Decoder), or
/// a [`Snag`](https://hexdocs.pm/snag/snag.html#Snag) on failure.
///
pub fn decode_every(
  from toml: Toml,
  get key_path: List(String),
  expect decoder: Decoder(a),
) -> Result(List(#(String, a)), Snag) {
  do_decode_every(toml, key_path, decoder)
}

@target(erlang)
fn do_decode_every(
  toml: Toml,
  key_path: List(String),
  decoder: Decoder(a),
) -> Result(List(#(String, a)), Snag) {
  use dict <- result.try(
    key_path
    |> decode(
      from: toml,
      expect: dynamic.from
        |> function.compose(dynamic.dict(
          of: dynamic.string,
          to: dynamic.dynamic,
        )),
    ),
  )

  dict
  |> dict.to_list
  |> list.filter_map(with: fn(tuple) {
    let key = ""
    let assert Ok(toml) =
      [#(key, tuple)]
      |> dict.from_list
      |> dynamic.from
      |> from_dynamic
    [key]
    |> decode(
      from: toml,
      expect: dynamic.tuple2(first: dynamic.string, second: decoder),
    )
  })
  |> Ok
}

@target(javascript)
fn do_decode_every(
  toml: Toml,
  key_path: List(String),
  decoder: Decoder(a),
) -> Result(List(#(String, a)), Snag) {
  toml
  |> javascript_decode_every(key_path, decoder)
  |> result.map_error(with: decode_errors_to_snag(_, key_path))
}

@target(javascript)
@external(javascript, "../rad_ffi.mjs", "toml_decode_every")
fn javascript_decode_every(
  toml: Toml,
  key_path: List(String),
  decoder: Decoder(a),
) -> Result(List(#(String, a)), DecodeErrors)

/// Results in a [`Toml`](#Toml) decoded from the given dynamic `data` on
/// success, or
/// [`DecodeErrors`](https://hexdocs.pm/gleam_stdlib/gleam/dynamic.html#DecodeErrors)
/// on failure.
///
pub fn from_dynamic(data: Dynamic) -> Result(Toml, DecodeErrors) {
  decode_object(data)
}

@external(erlang, "rad_ffi", "decode_object")
@external(javascript, "../rad_ffi.mjs", "decode_object")
fn decode_object(data: Dynamic) -> Result(Toml, DecodeErrors)

/// Returns a new, empty [`Toml`](#Toml).
///
pub fn new() -> Toml {
  do_new()
}

@external(erlang, "rad_ffi", "toml_new")
@external(javascript, "../rad_ffi.mjs", "toml_new")
fn do_new() -> Toml

/// Results in a [`Toml`](#Toml) parsed from the given file `path` on success,
/// or a [`Snag`](https://hexdocs.pm/snag/snag.html#Snag) on failure.
///
pub fn parse_file(path: String) -> Result(Toml, Snag) {
  path
  |> do_parse_file
  |> result.map_error(with: fn(_nil) {
    ["failed parsing file `", path, "`"]
    |> string.concat
    |> snag.new
  })
  |> result.try(apply: fn(parsed) {
    parsed
    |> from_dynamic
    |> result.map_error(with: fn(_decode_errors) {
      ["invalid TOML file `", path, "`"]
      |> string.concat
      |> snag.new
    })
  })
}

@external(erlang, "rad_ffi", "toml_read_file")
@external(javascript, "../rad_ffi.mjs", "toml_read_file")
fn do_parse_file(path: String) -> Result(Dynamic, Nil)

fn decode_errors_to_snag(decode_errors: DecodeErrors, key_path: List(String)) {
  let assert [head, ..rest] =
    decode_errors
    |> list.map(with: fn(error: DecodeError) {
      let path = case error.path == [] {
        False -> path_message(" at `", error.path, "`")
        True -> ""
      }
      ["expected ", error.expected, " but found ", error.found, path]
      |> string.concat
    })
  rest
  |> list.fold(from: snag.new(head), with: snag.layer)
  |> snag.layer(path_message("failed to decode item `", key_path, "`"))
}

fn path_message(prefix: String, path: List(String), suffix: String) -> String {
  [prefix, string.join(path, with: "."), suffix]
  |> string.concat
}
