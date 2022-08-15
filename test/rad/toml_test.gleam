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
  |> toml.decode(from: toml, expect: dynamic.list(of: dynamic.string))
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
    |> toml.decode(from: toml, expect: dynamic.list(of: toml.from_dynamic))

  tasks
  |> list.find(one_that: fn(task) {
    assert Ok(lists) =
      []
      |> toml.decode_every(from: task, expect: dynamic.list(of: dynamic.string))
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
