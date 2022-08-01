import gleam/dynamic
import gleam/list
import gleam/result
import gleeunit/should
import rad/toml
import rad/util

pub fn new_test() {
  toml.new()
  |> toml.decode(get: [], expect: toml.from_dynamic)
  |> result.map(with: util.encode_json)
  |> should.equal(Ok("{}"))
}

pub fn parse_file_test() {
  assert Ok(toml) =
    "gleam.toml"
    |> toml.parse_file

  ["name"]
  |> toml.decode(from: toml, expect: dynamic.string)
  |> should.equal(Ok("rad"))

  let file = "src/rad/toml.gleam"

  file
  |> util.file_exists
  |> should.be_true

  file
  |> toml.parse_file
  |> should.be_error

  let file = "gloom.toml"

  file
  |> util.file_exists
  |> should.be_false

  file
  |> toml.parse_file
  |> should.be_error
}

pub fn from_dynamic_test() {
  let toml =
    "gleam.toml"
    |> toml.parse_file
    |> result.lazy_unwrap(or: toml.new)

  []
  |> toml.decode(from: toml, expect: toml.from_dynamic)
  |> should.be_ok

  ["dependencies"]
  |> toml.decode(from: toml, expect: toml.from_dynamic)
  |> should.be_ok

  ["name"]
  |> toml.decode(from: toml, expect: toml.from_dynamic)
  |> should.be_error

  "{}"
  |> dynamic.from
  |> toml.from_dynamic
  |> should.be_error
}

pub fn decode_test() {
  assert Ok(toml) =
    "gleam.toml"
    |> toml.parse_file

  ["rad", "workbook"]
  |> toml.decode(from: toml, expect: dynamic.string)
  |> should.equal(Ok("rad/workbook/standard"))

  ["rad", "targets"]
  // TODO: swap for gleam_stdlib > 0.22.1
  //|> toml.decode(from: toml, expect: dynamic.list(of: dynamic.string))
  |> toml.decode(from: toml, expect: dynamic_list(of: dynamic.string))
  |> should.equal(Ok(["erlang", "javascript"]))

  ["rad", "workbook"]
  |> toml.decode(from: toml, expect: dynamic.dynamic)
  |> should.be_ok

  ["rad", "workbook"]
  |> toml.decode(from: toml, expect: dynamic.int)
  |> should.be_error

  ["rad", "gloom"]
  |> toml.decode(from: toml, expect: dynamic.dynamic)
  |> should.be_error
}

pub fn decode_every_test() {
  assert Ok(toml) =
    "gleam.toml"
    |> toml.parse_file

  assert Ok(strings) =
    []
    |> toml.decode_every(from: toml, expect: dynamic.string)

  strings
  |> list.key_find(find: "name")
  |> should.equal(Ok("rad"))

  strings
  |> list.key_find(find: "licences")
  |> should.be_error

  assert Ok(tasks) =
    ["rad", "tasks"]
    // TODO: swap for gleam_stdlib > 0.22.1
    //|> toml.decode(from: toml, expect: dynamic.list(of: toml.from_dynamic))
    |> toml.decode(from: toml, expect: dynamic_list(of: toml.from_dynamic))

  tasks
  |> list.find(one_that: fn(task) {
    assert Ok(lists) =
      []
      // TODO: swap for gleam_stdlib > 0.22.1
      //|> toml.decode_every(from: task, expect: dynamic.list(of: dynamic.string))
      |> toml.decode_every(from: task, expect: dynamic_list(of: dynamic.string))
    assert Ok(path) =
      "path"
      |> list.key_find(in: lists)
    path == ["sparkles"]
  })
  |> should.be_ok

  ["rad"]
  |> toml.decode_every(from: toml, expect: dynamic.dynamic)
  |> should.be_ok

  ["dependencies"]
  |> toml.decode_every(from: toml, expect: dynamic.int)
  |> should.equal(Ok([]))

  ["rad", "gloom"]
  |> toml.decode_every(from: toml, expect: dynamic.dynamic)
  |> should.be_error
}

// TODO: remove for gleam_stdlib > 0.22.1
fn dynamic_list(
  of decoder_type: fn(dynamic.Dynamic) -> Result(a, dynamic.DecodeErrors),
) -> dynamic.Decoder(List(a)) {
  do_dynamic_list(decoder_type)
}

if erlang {
  fn do_dynamic_list(decoder_type) {
    dynamic.list(of: decoder_type)
  }
}

if javascript {
  import gleam/int
  import gleam/string

  fn do_dynamic_list(decoder_type) {
    fn(dynamic) {
      try list = decode_list(dynamic)
      list
      |> list.try_map(decoder_type)
      |> result.map_error(with: list.map(_, with: push_path(_, "*")))
    }
  }

  fn push_path(error, name) {
    let name = dynamic.from(name)
    let decoder =
      dynamic.any([
        dynamic.string,
        fn(x) { result.map(dynamic.int(x), int.to_string) },
      ])
    let name = case decoder(name) {
      Ok(name) -> name
      Error(_) ->
        ["<", dynamic.classify(name), ">"]
        |> string.concat
    }
    dynamic.DecodeError(..error, path: [name, ..error.path])
  }

  external fn decode_list(
    dynamic.Dynamic,
  ) -> Result(List(dynamic.Dynamic), dynamic.DecodeErrors) =
    "../rad_ffi.mjs" "tmp_decode_list"
}
