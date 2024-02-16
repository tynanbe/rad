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
    ["-noshell", "-eval", "rad@@main:run(" <> module <> ")"]
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
  let assert Ok(ebin_paths) = util.ebin_paths()
  ebin_paths
  |> list.find(one_that: fn(path) { path == "./build/dev/erlang/rad/ebin" })
  |> should.be_ok
}

pub fn javascript_run_test() {
  let run_module = fn(module) {
    let script =
      "import('./build/dev/javascript/rad/"
      <> module
      <> ".mjs').then(module => module.main())"
    util.javascript_run(
      deno: ["eval", script, "--unstable"],
      or: ["--eval=" <> script],
      opt: [],
    )
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

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Miscellaneous Functions                //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

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

pub fn relay_flags_test() {
  [
    #(
      "rad-test",
      flag.bool()
        |> flag.default(of: True)
        |> flag.build,
    ),
    #(
      "eevee",
      flag.bool()
        |> flag.default(of: False)
        |> flag.build,
    ),
    #(
      "vaporeon",
      flag.float()
        |> flag.default(of: 1.0)
        |> flag.build,
    ),
    #(
      "jolteon",
      flag.float_list()
        |> flag.default(of: [2.0, 0.2])
        |> flag.build,
    ),
    #(
      "flareon",
      flag.int()
        |> flag.default(of: 3)
        |> flag.build,
    ),
    #(
      "espeon",
      flag.int_list()
        |> flag.default(of: [4, 0, 4])
        |> flag.build,
    ),
    #(
      "umbreon",
      flag.string()
        |> flag.default(of: "5")
        |> flag.build,
    ),
    #(
      "ditto",
      flag.string_list()
        |> flag.default(of: ["eevee"])
        |> flag.build,
    ),
  ]
  |> flag.build_map
  |> util.relay_flags
  |> list.sort(by: string.compare)
  |> should.equal([
    "--ditto=eevee", "--espeon=4,0,4", "--flareon=3", "--jolteon=2.0,0.2",
    "--umbreon=5", "--vaporeon=1.0",
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
