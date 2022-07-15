import gleam/list
import gleam/string
import gleeunit/should
import glint/flag
import rad/toml
import rad/util

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Runtime Functions                      //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

pub fn erlang_run_test() {
  let run_module = fn(module) {
    let expression =
      ["gleam@@main:run(", module, ")"]
      |> string.concat
    ["-noshell", "-eval", expression]
    |> util.erlang_run(opt: [])
  }

  "rad"
  |> run_module
  |> should.be_ok

  "rad@rattata"
  |> run_module
  |> should.be_error
}

pub fn ebin_paths_test() {
  assert Ok(ebin_paths) = util.ebin_paths()
  ebin_paths
  |> list.find(one_that: fn(path) { path == "./build/dev/erlang/rad/ebin" })
  |> should.be_ok
}

pub fn javascript_run_test() {
  let run_module = fn(module) {
    [
      "--eval=import('./build/dev/javascript/rad/dist/",
      module,
      ".mjs').then(module => module.main())",
    ]
    |> string.concat
    |> list.repeat(times: 1)
    |> util.javascript_run(opt: [])
  }

  "rad"
  |> run_module
  |> should.be_ok

  "rad/raticate"
  |> run_module
  |> should.be_error
}

pub fn refuse_erlang_test() {
  util.refuse_erlang()
  |> should.be_error
}

pub fn relay_flags_test() {
  [
    "rad-test"
    |> flag.bool(default: True, explained: ""),
    "eevee"
    |> flag.bool(default: False, explained: ""),
    "vaporeon"
    |> flag.float(default: 1., explained: ""),
    "jolteon"
    |> flag.floats(default: [2., 0.2], explained: ""),
    "flareon"
    |> flag.int(default: 3, explained: ""),
    "espeon"
    |> flag.ints(default: [4, 0, 4], explained: ""),
    "umbreon"
    |> flag.string(default: "5", explained: ""),
    "ditto"
    |> flag.strings(default: ["eevee"], explained: ""),
  ]
  |> flag.build_map
  |> util.relay_flags
  |> list.sort(by: string.compare)
  |> should.equal([
    "--ditto=eevee", "--espeon=4,0,4", "--flareon=3", "--jolteon=2.0,0.2", "--umbreon=5",
    "--vaporeon=1.0",
  ])

  []
  |> flag.build_map
  |> util.relay_flags
  |> should.equal([])
}

pub fn which_rad_test() {
  util.which_rad()
  |> string.contains(contain: "/rad")
  |> should.be_true
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// TOML Helper Functions                  //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

pub fn dependency_test() {
  let name = "gleam_stdlib"
  [name]
  |> util.dependency
  |> should.equal(Ok(name))

  ["meowth"]
  |> util.dependency
  |> should.be_error

  []
  |> util.dependency
  |> should.be_error
}

pub fn encode_json_test() {
  False
  |> util.encode_json
  |> should.equal("false")

  1
  |> util.encode_json
  |> should.equal("1")

  2.3
  |> util.encode_json
  |> should.equal("2.3")

  "4"
  |> util.encode_json
  |> should.equal("\"4\"")

  toml.new()
  |> util.encode_json
  |> should.equal("{}")
}

pub fn packages_test() {
  let name = "gleam_stdlib"
  [name]
  |> util.packages
  |> should.be_ok

  ["celebi"]
  |> util.dependency
  |> should.be_error

  []
  |> util.dependency
  |> should.be_error
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// File System Functions                  //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

pub fn rename_test() {
  let pathname = fn(name) {
    ["./build", name]
    |> string.join(with: "/")
  }
  let missingno = pathname("missingno")
  let rhydon = pathname("rhydon")

  missingno
  |> util.file_exists
  |> should.be_false

  missingno
  |> util.rename(to: rhydon)
  |> should.be_error

  missingno
  |> util.file_write(contents: "")
  |> should.be_ok

  missingno
  |> util.rename(to: rhydon)
  |> should.be_ok

  rhydon
  |> util.recursive_delete
  |> should.be_ok
}
