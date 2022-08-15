import gleam/map
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
  |> map.get([])
  |> should.be_ok

  workbook
  |> map.get(["help"])
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

  let flags = [flag.bool(called: "version", default: False, explained: "")]

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
  // TODO: swap for Gleam > 0.22.1
  //let task =
  //  ["config"]
  //  |> rad_test.task(from: standard.workbook())
  let task = rad_test.task(from: standard.workbook(), at: ["config"])

  assert Ok(deps) =
    ["dependencies"]
    |> rad_test.input(flags: flags)
    |> rad_test.run(task)

  assert Ok(tasks) =
    ["rad", "tasks"]
    |> rad_test.input(flags: flags)
    |> rad_test.run(task)

  tasks
  |> should.not_equal(deps)

  assert Ok(json) =
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
  let flags = [flag.bool(called: "all", default: False, explained: "")]
  // TODO: swap for Gleam > 0.22.1
  //let task =
  //  ["name"]
  //  |> rad_test.task(from: standard.workbook())
  let task = rad_test.task(from: standard.workbook(), at: ["name"])

  assert Ok(rad) =
    []
    |> rad_test.input(flags: flags)
    |> rad_test.run(task)

  assert Ok(stdlib) =
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
  // TODO: swap for Gleam > 0.22.1
  //let task =
  //  ["origin"]
  //  |> rad_test.task(from: standard.workbook())
  let task = rad_test.task(from: standard.workbook(), at: ["origin"])
  []
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> should.be_ok
}

pub fn ping_test() {
  let flags = []
  // TODO: swap for Gleam > 0.22.1
  //let task =
  //  ["ping"]
  //  |> rad_test.task(from: standard.workbook())
  let task = rad_test.task(from: standard.workbook(), at: ["ping"])

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
  // TODO: swap for Gleam > 0.22.1
  //let task =
  //  ["tree"]
  //  |> rad_test.task(from: standard.workbook())
  let task = rad_test.task(from: standard.workbook(), at: ["tree"])

  let should_result =
    "exa"
    |> shellout.which
    |> result.lazy_or(fn() { shellout.which("tree") })
    |> result.replace(should.be_ok)
    |> result.unwrap(or: should.be_error)

  []
  |> rad_test.input(flags: flags)
  |> rad_test.run(task)
  |> should_result
}

pub fn version_test() {
  let flags = [
    flag.bool(called: "all", default: False, explained: ""),
    flag.bool(called: "bare", default: False, explained: ""),
  ]
  // TODO: swap for Gleam > 0.22.1
  //let task =
  //  ["version"]
  //  |> rad_test.task(from: standard.workbook())
  let task = rad_test.task(from: standard.workbook(), at: ["version"])

  assert Ok(bare) =
    ["--bare"]
    |> rad_test.input(flags: flags)
    |> rad_test.run(task)

  assert Ok(rad) =
    []
    |> rad_test.input(flags: flags)
    |> rad_test.run(task)

  rad
  |> should.not_equal(bare)
  rad
  |> string.contains(contain: bare)
  |> should.equal(True)

  assert Ok(stdlib) =
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
