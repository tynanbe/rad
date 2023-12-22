import gleam/dict
import gleam/result
import gleam/string
import gleeunit/should
import glint/flag
import rad/workbook/standard
import rad_test
import shellout

pub fn workbook_test() {
  let workbook = standard.workbook()

  workbook
  |> dict.get([])
  |> should.be_ok

  workbook
  |> dict.get(["help"])
  |> should.be_ok
}

pub fn root_test() {
  let workbook = standard.workbook()

  let root =
    []
    |> rad_test.task(from: workbook)

  let help =
    ["help"]
    |> rad_test.task(from: workbook)

  let help =
    rad_test.empty_input()
    |> rad_test.run(help)

  help
  |> should.be_ok

  let flags = [
    #(
      "version",
      flag.bool()
      |> flag.default(of: False)
      |> flag.build,
    ),
  ]

  []
  |> rad_test.input(flags: flags)
  |> rad_test.run(root)
  |> should.equal(help)

  let version =
    ["--version"]
    |> rad_test.input(flags: flags)
    |> rad_test.run(root)

  version
  |> should.be_ok
  version
  |> should.not_equal(help)
}

pub fn config_test() {
  let flags = []
  let task =
    ["config"]
    |> rad_test.task(from: standard.workbook())

  let assert Ok(deps) =
    ["dependencies"]
    |> rad_test.input(flags: flags)
    |> rad_test.run(task)

  let assert Ok(tasks) =
    ["rad", "tasks"]
    |> rad_test.input(flags: flags)
    |> rad_test.run(task)

  tasks
  |> should.not_equal(deps)

  let assert Ok(json) =
    []
    |> rad_test.input(flags: flags)
    |> rad_test.run(task)

  json
  |> should.not_equal(deps)
  json
  |> string.contains(contain: deps)
  |> should.equal(True)
  json
  |> should.not_equal(tasks)
  json
  |> string.contains(contain: tasks)
  |> should.equal(True)

  [""]
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> should.be_error

  ["rad", "unown"]
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> should.be_error
}

pub fn name_test() {
  let flags = [
    #(
      "all",
      flag.bool()
      |> flag.default(of: False)
      |> flag.build,
    ),
  ]
  let task =
    ["name"]
    |> rad_test.task(from: standard.workbook())

  let assert Ok(rad) =
    []
    |> rad_test.input(flags: flags)
    |> rad_test.run(task)

  let assert Ok(stdlib) =
    ["gleam_stdlib"]
    |> rad_test.input(flags: flags)
    |> rad_test.run(task)

  stdlib
  |> should.not_equal(rad)

  ["--all"]
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> should.be_ok

  [""]
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> should.be_error

  ["wobbuffet"]
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> should.be_error
}

pub fn origin_test() {
  let flags = []
  let task =
    ["origin"]
    |> rad_test.task(from: standard.workbook())
  []
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> should.be_ok
}

pub fn ping_test() {
  let flags = []
  let task =
    ["ping"]
    |> rad_test.task(from: standard.workbook())

  ["http://example.com/"]
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> should.equal(Ok("200"))

  ["http://example.com/", "http://www.example.com/"]
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> should.equal(Ok(""))

  []
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> should.be_error
}

pub fn tree_test() {
  let flags = []
  let task =
    ["tree"]
    |> rad_test.task(from: standard.workbook())

  let should_result =
    "exa"
    |> shellout.which
    |> result.lazy_or(fn() { shellout.which("tree") })
    |> result.replace(should.be_ok)
    |> result.unwrap(or: should.be_error)

  []
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> result.replace_error("")
  |> should_result
}

pub fn version_test() {
  let flags = [
    #(
      "all",
      flag.bool()
      |> flag.default(of: False)
      |> flag.build,
    ),
    #(
      "bare",
      flag.bool()
      |> flag.default(of: False)
      |> flag.build,
    ),
  ]
  let task =
    ["version"]
    |> rad_test.task(from: standard.workbook())

  let assert Ok(bare) =
    ["--bare"]
    |> rad_test.input(flags: flags)
    |> rad_test.run(task)

  let assert Ok(rad) =
    []
    |> rad_test.input(flags: flags)
    |> rad_test.run(task)

  rad
  |> should.not_equal(bare)
  rad
  |> string.contains(contain: bare)
  |> should.equal(True)

  let assert Ok(stdlib) =
    ["gleam_stdlib"]
    |> rad_test.input(flags: flags)
    |> rad_test.run(task)

  stdlib
  |> should.not_equal(rad)

  ["--all"]
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> should.be_ok

  [""]
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> should.be_error

  ["ho-oh"]
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> should.be_error
}
