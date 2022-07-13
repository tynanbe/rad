//// TODO
////

import gleam/dynamic.{DecodeError, DecodeErrors, Decoder, Dynamic}
import gleam/list
import gleam/result
import gleam/string
import snag.{Snag}

if erlang {
  import gleam/function
  import gleam/map
}

/// TODO
///
pub external type Toml

/// TODO
///
pub fn decode(
  from toml: Toml,
  get key_path: List(String),
  expect decoder: Decoder(a),
) -> Result(a, Snag) {
  try item =
    toml
    |> do_toml_get(key_path)
    |> result.map_error(with: fn(_nil) {
      path_message("failed to find item `", key_path, "`")
      |> snag.new
    })

  item
  |> decoder
  |> result.map_error(with: decode_errors_to_snag(_, key_path))
}

if erlang {
  fn do_toml_get(toml: Toml, key_path: List(String)) -> Result(Dynamic, Nil) {
    toml
    |> erlang_toml_get(key_path)
    |> result.nil_error
  }

  external fn erlang_toml_get(Toml, List(String)) -> Result(Dynamic, Dynamic) =
    "tomerl" "get"
}

if javascript {
  external fn do_toml_get(Toml, List(String)) -> Result(Dynamic, Nil) =
    "../rad_ffi.mjs" "toml_get"
}

/// TODO
///
pub fn decode_every(
  from toml: Toml,
  get key_path: List(String),
  expect decoder: Decoder(a),
) -> Result(List(#(String, a)), Snag) {
  do_decode_every(toml, key_path, decoder)
}

if erlang {
  fn do_decode_every(
    toml: Toml,
    key_path: List(String),
    decoder: Decoder(a),
  ) -> Result(List(#(String, a)), Snag) {
    try map =
      key_path
      |> decode(
        from: toml,
        expect: dynamic.from
        |> function.compose(dynamic.map(of: dynamic.string, to: dynamic.dynamic)),
      )

    map
    |> map.to_list
    |> list.filter_map(with: fn(tuple) {
      let key = ""
      assert Ok(toml) =
        [#(key, tuple)]
        |> map.from_list
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
}

if javascript {
  fn do_decode_every(
    toml: Toml,
    key_path: List(String),
    decoder: Decoder(a),
  ) -> Result(List(#(String, a)), Snag) {
    toml
    |> javascript_decode_every(key_path, decoder)
    |> result.map_error(with: decode_errors_to_snag(_, key_path))
  }

  external fn javascript_decode_every(
    Toml,
    List(String),
    Decoder(a),
  ) -> Result(List(#(String, a)), DecodeErrors) =
    "../rad_ffi.mjs" "toml_decode_every"
}

/// TODO
///
pub fn from_dynamic(data: Dynamic) -> Result(Toml, DecodeErrors) {
  decode_object(data)
}

if erlang {
  external fn decode_object(Dynamic) -> Result(Toml, DecodeErrors) =
    "gleam_stdlib" "decode_map"
}

if javascript {
  external fn decode_object(Dynamic) -> Result(Toml, DecodeErrors) =
    "../rad_ffi.mjs" "decode_object"
}

/// TODO
///
pub fn new() -> Toml {
  do_new()
}

if erlang {
  external fn do_new() -> Toml =
    "maps" "new"
}

if javascript {
  external fn do_new() -> Toml =
    "" "globalThis.Object.prototype.constructor"
}

/// TODO
///
pub fn parse_file(path: String) -> Result(Toml, Snag) {
  path
  |> do_parse_file
  |> result.map_error(with: fn(_nil) {
    ["failed parsing file `", path, "`"]
    |> string.concat
    |> snag.new
  })
  |> result.then(apply: fn(parsed) {
    parsed
    |> from_dynamic
    |> result.map_error(with: fn(_decode_errors) {
      ["invalid TOML file `", path, "`"]
      |> string.concat
      |> snag.new
    })
  })
}

if erlang {
  fn do_parse_file(path: String) -> Result(Dynamic, Nil) {
    path
    |> erlang_parse_file
    |> result.nil_error
  }

  external fn erlang_parse_file(String) -> Result(Dynamic, Dynamic) =
    "tomerl" "read_file"
}

if javascript {
  external fn do_parse_file(String) -> Result(Dynamic, Nil) =
    "../rad_ffi.mjs" "toml_read_file"
}

fn decode_errors_to_snag(decode_errors: DecodeErrors, key_path: List(String)) {
  let [head, ..rest] =
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
