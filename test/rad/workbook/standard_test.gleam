import gleam/map
import gleam/result
import gleam/string
import gleeunit/should
import glint/flag
import rad/workbook/standard
import rad_test.{empty_input, input, run, task}
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
    |> task(from: workbook)

  let help =
    ["help"]
    |> task(from: workbook)

  let help =
    empty_input()
    |> run(help)

  help
  |> should.be_ok

  let flags = [flag.bool(called: "version", default: False, explained: "")]

  []
  |> input(flags: flags)
  |> run(root)
  |> should.equal(help)

  let version =
    ["--version"]
    |> input(flags: flags)
    |> run(root)

  version
  |> should.be_ok
  version
  |> should.not_equal(help)
}

pub fn config_test() {
  let flags = []
  // TODO: swap out after bugfix
  //let task =
  //  ["config"]
  //  |> task(from: standard.workbook())
  let task = task(from: standard.workbook(), at: ["config"])

  assert Ok(deps) =
    ["dependencies"]
    |> input(flags: flags)
    |> run(task)

  assert Ok(tasks) =
    ["rad", "tasks"]
    |> input(flags: flags)
    |> run(task)

  tasks
  |> should.not_equal(deps)

  assert Ok(json) =
    []
    |> input(flags: flags)
    |> run(task)

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
  |> input(flags: flags)
  |> run(task)
  |> should.be_error

  ["rad", "unown"]
  |> input(flags: flags)
  |> run(task)
  |> should.be_error
}

pub fn name_test() {
  // TODO: swap out after implementation
  //let flags = [flag.bool(called: "all", default: False, explained: "")]
  let flags = []
  // TODO: swap out after bugfix
  //let task =
  //  ["name"]
  //  |> task(from: standard.workbook())
  let task = task(from: standard.workbook(), at: ["name"])

  assert Ok(rad) =
    []
    |> input(flags: flags)
    |> run(task)

  assert Ok(stdlib) =
    ["gleam_stdlib"]
    |> input(flags: flags)
    |> run(task)

  stdlib
  |> should.not_equal(rad)

  //assert Ok(all) =
  //  ["--all"]
  //  |> input(flags: flags)
  //  |> run(task)
  //
  //all
  //|> should.not_equal(rad)
  //all
  //|> string.contains(contain: rad)
  //|> should.equal(True)
  //all
  //|> should.not_equal(stdlib)
  //all
  //|> string.contains(contain: stdlib)
  //|> should.equal(True)
  [""]
  |> input(flags: flags)
  |> run(task)
  |> should.be_error

  ["wobbuffet"]
  |> input(flags: flags)
  |> run(task)
  |> should.be_error
}

pub fn origin_test() {
  let flags = []
  // TODO: swap out after bugfix
  //let task =
  //  ["origin"]
  //  |> task(from: standard.workbook())
  let task = task(from: standard.workbook(), at: ["origin"])
  []
  |> input(flags: flags)
  |> run(task)
  |> should.be_ok
}

pub fn ping_test() {
  let flags = []
  // TODO: swap out after bugfix
  //let task =
  //  ["ping"]
  //  |> task(from: standard.workbook())
  let task = task(from: standard.workbook(), at: ["ping"])

  ["http://example.com/"]
  |> input(flags: flags)
  |> run(task)
  |> should.equal(Ok("200"))

  ["http://example.com/", "http://www.example.com/"]
  |> input(flags: flags)
  |> run(task)
  |> should.equal(Ok(""))

  []
  |> input(flags: flags)
  |> run(task)
  |> should.be_error
}

pub fn tree_test() {
  let flags = []
  // TODO: swap out after bugfix
  //let task =
  //  ["tree"]
  //  |> task(from: standard.workbook())
  let task = task(from: standard.workbook(), at: ["tree"])

  let should_result =
    "exa"
    |> shellout.which
    |> result.lazy_or(fn() { shellout.which("tree") })
    |> result.replace(should.be_ok)
    |> result.unwrap(or: should.be_error)

  []
  |> input(flags: flags)
  |> run(task)
  |> should_result
}

pub fn version_test() {
  // TODO: swap out after implementation
  //let flags = [flag.bool(called: "all", default: False, explained: "")]
  let flags = [flag.bool(called: "bare", default: False, explained: "")]
  // TODO: swap out after bugfix
  //let task =
  //  ["version"]
  //  |> task(from: standard.workbook())
  let task = task(from: standard.workbook(), at: ["version"])

  assert Ok(bare) =
    ["--bare"]
    |> input(flags: flags)
    |> run(task)

  assert Ok(rad) =
    []
    |> input(flags: flags)
    |> run(task)

  rad
  |> should.not_equal(bare)
  rad
  |> string.contains(contain: bare)
  |> should.equal(True)

  assert Ok(stdlib) =
    ["gleam_stdlib"]
    |> input(flags: flags)
    |> run(task)

  stdlib
  |> should.not_equal(rad)

  //assert Ok(all) =
  //  ["--all"]
  //  |> input(flags: flags)
  //  |> run(task)
  //
  //all
  //|> should.not_equal(rad)
  //all
  //|> string.contains(contain: rad)
  //|> should.equal(True)
  //all
  //|> should.not_equal(stdlib)
  //all
  //|> string.contains(contain: stdlib)
  //|> should.equal(True)
  [""]
  |> input(flags: flags)
  |> run(task)
  |> should.be_error

  ["ho-oh"]
  |> input(flags: flags)
  |> run(task)
  |> should.be_error
}
