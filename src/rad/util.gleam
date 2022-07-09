//// A motley assortment of utility functions.
////

import gleam/dynamic
import gleam/float
import gleam/function
import gleam/http.{Header}
import gleam/int
import gleam/list
import gleam/map
import gleam/option.{Some}
import gleam/result
import gleam/string
import gleam/uri.{Uri}
import glint/flag
import rad/toml
import shellout.{CommandOpt, Lookups}
import snag.{Snag}

if erlang {
  import gleam/erlang/atom
  import gleam/erlang/file
  import gleam/http/request
  import gleam/httpc

  type Dynamic =
    dynamic.Dynamic
}

if javascript {
  import gleam/json
}

/// TODO
///
pub const lookups: Lookups = [
  #(
    ["color", "background"],
    [
      #("boi-blue", ["166", "240", "252"]),
      #("buttercup", ["255", "215", "175"]),
      #("hot-pink", ["217", "0", "184"]),
      #("mint", ["182", "255", "234"]),
      #("peach", ["255", "175", "194"]),
      #("pink", ["255", "175", "243"]),
      #("purple", ["217", "181", "255"]),
    ],
  ),
]

/// TODO
///
pub const rad_path = "./build/dev/javascript/rad"

/// Results in the name of an installed dependency on success, or an error on
/// failure, such as when the depency isn't found.
///
pub fn dependency(args: List(String)) -> Result(String, Snag) {
  try _version =
    args
    |> packages
    |> result.map_error(with: fn(_snag) {
      ["dependency `", string.join(args, with: "."), "` not found"]
      |> string.concat
      |> snag.new
    })
  let [name] = args
  Ok(name)
}

/// TODO
///
pub fn ebin_paths() -> Result(List(String), Nil) {
  do_ebin_paths()
}

if erlang {
  fn do_ebin_paths() -> Result(List(String), Nil) {
    let prefix = "./build/dev/erlang"
    prefix
    |> file.list_directory
    |> result.map(with: list.map(_, with: fn(subdirectory) {
      [prefix, subdirectory, "ebin"]
      |> string.join(with: "/")
    }))
    |> result.nil_error
  }
}

if javascript {
  external fn do_ebin_paths() -> Result(List(String), Nil) =
    "../rad_ffi.mjs" "ebin_paths"
}

/// TODO
///
pub fn erlang_run(
  with args: List(String),
  opt options: List(CommandOpt),
) -> Result(String, Snag) {
  ebin_paths()
  |> result.replace_error(snag.new("failed to find `ebin` paths"))
  |> result.then(apply: fn(ebins) {
    [["-pa", ..ebins], args]
    |> list.flatten
    |> shellout.command(run: "erl", in: ".", opt: options)
    |> result.replace_error(snag.new("failed to run `erl`"))
  })
}

/// TODO
///
pub fn is_directory(path: String) -> Bool {
  do_is_directory(path)
}

if erlang {
  fn do_is_directory(path: String) -> Bool {
    file.is_directory(path)
  }
}

if javascript {
  external fn do_is_directory(String) -> Bool =
    "../rad_ffi.mjs" "is_directory"
}

/// TODO
///
pub fn is_file(path: String) -> Bool {
  do_is_file(path)
}

if erlang {
  fn do_is_file(path: String) -> Bool {
    file.is_file(path)
  }
}

if javascript {
  external fn do_is_file(String) -> Bool =
    "../rad_ffi.mjs" "is_file"
}

/// TODO
///
pub fn javascript_run(
  with args: List(String),
  opt options: List(CommandOpt),
) -> Result(String, Snag) {
  ["--experimental-fetch", "--experimental-repl-await", "--no-warnings", ..args]
  |> shellout.command(run: "node", in: ".", opt: options)
  |> result.replace_error(snag.new("failed to run `node`"))
}

/// TODO
///
pub fn packages(path: List(String)) -> Result(String, Snag) {
  try toml =
    "build/packages/packages.toml"
    |> toml.parse_file

  ["packages", ..path]
  |> toml.decode(from: toml, expect: dynamic.string)
}

/// TODO
///
pub fn ping(uri_string: String) -> Result(Int, Int) {
  assert Ok(uri) = uri.parse(uri_string)
  case uri.host {
    Some("localhost") -> Uri(..uri, host: Some("127.0.0.1"))
    _else -> uri
  }
  |> uri.to_string
  |> do_ping([#("cache-control", "no-cache, no-store")])
}

if erlang {
  fn do_ping(uri_string: String, headers: List(Header)) -> Result(Int, Int) {
    try uri =
      uri_string
      |> uri.parse
      |> result.replace_error(400)

    try request =
      uri
      |> request.from_uri
      |> result.replace_error(400)

    headers
    |> list.fold(
      from: request,
      with: fn(acc, header) { request.prepend_header(acc, header.0, header.1) },
    )
    |> httpc.send
    |> result.map(with: fn(response) { response.status })
    |> result.replace_error(503)
  }
}

if javascript {
  fn do_ping(uri_string: String, headers: List(Header)) -> Result(Int, Int) {
    let headers =
      headers
      |> list.map(with: fn(header) { #(header.0, json.string(header.1)) })
      |> json.object
      |> json.to_string

    let script =
      [
        ["fetch('", uri_string, "', ", headers, ")"],
        [".then((response) => response.status)"],
        [".catch(() => 503)"],
        [".then(console.log)"],
        [".then(() => process.exit(0))"],
      ]
      |> list.flatten
      |> string.concat
    try status =
      ["--eval", script]
      |> javascript_run(opt: [])
      |> result.replace_error(503)

    assert Ok(status) =
      status
      |> string.trim
      |> int.parse
    case status < 400 {
      True -> Ok(status)
      False -> Error(status)
    }
  }
}

/// Results in an error meant to notify users that a task cannot be carried out
/// using the Erlang runtime.
///
pub fn refuse_erlang() -> Result(String, Snag) {
  "task cannot be run with erlang"
  |> snag.error
  |> snag.context("failed to run task")
}

/// TODO
///
pub fn relay_flags(flags: flag.Map) -> List(String) {
  flags
  |> map.to_list
  |> list.filter_map(with: fn(flag) {
    let #(key, flag.Contents(value: value, ..)) = flag
    let relay_flag = fn(value: a, fun) {
      ["--", key, "=", fun(value)]
      |> string.concat
      |> Ok
    }
    let relay_multiflag = fn(value: List(a), fun) {
      list.map(_, with: fun)
      |> function.compose(string.join(_, with: ","))
      |> relay_flag(value, _)
    }

    case value {
      flag.B(value) if value ->
        ["--", key]
        |> string.concat
        |> Ok
      flag.F(value) -> relay_flag(value, float.to_string)
      flag.I(value) -> relay_flag(value, int.to_string)
      flag.LF(value) -> relay_multiflag(value, float.to_string)
      flag.LI(value) -> relay_multiflag(value, int.to_string)
      flag.LS(value) -> relay_multiflag(value, function.identity)
      flag.S(value) -> relay_flag(value, function.identity)
      _else -> Error(Nil)
    }
  })
}

/// TODO
///
pub fn recursive_delete(path: String) -> Result(String, Snag) {
  path
  |> do_recursive_delete
  |> result.replace("")
  |> result.map_error(with: fn(_reason) {
    ["failed to delete `", path, "`"]
    |> string.concat
    |> snag.new
  })
}

if erlang {
  fn do_recursive_delete(path: String) -> Result(Nil, file.Reason) {
    file.recursive_delete(path)
  }
}

if javascript {
  external fn do_recursive_delete(String) -> Result(Nil, String) =
    "../rad_ffi.mjs" "recursive_delete"
}

/// TODO
///
pub fn rename(from source: String, to dest: String) -> Result(String, Snag) {
  source
  |> do_rename(dest)
  |> result.replace("")
  |> result.map_error(with: fn(_reason) {
    ["failed to rename `", source, "` to `", dest, "`"]
    |> string.concat
    |> snag.new
  })
}

if erlang {
  fn do_rename(source: String, dest: String) -> Result(Dynamic, Dynamic) {
    source
    |> erlang_rename(dest)
    |> dynamic.any(of: [
      fn(data) {
        data
        |> atom.from_dynamic
        |> result.map(with: fn(atom) {
          case atom == atom.create_from_string("ok") {
            True ->
              Nil
              |> dynamic.from
              |> Ok
            False ->
              atom
              |> dynamic.from
              |> Error
          }
        })
      },
      dynamic.result(ok: dynamic.dynamic, error: dynamic.dynamic),
    ])
    |> result.lazy_unwrap(or: fn() {
      Nil
      |> dynamic.from
      |> Error
    })
  }

  external fn erlang_rename(String, String) -> Dynamic =
    "file" "rename"
}

if javascript {
  external fn do_rename(String, String) -> Result(Nil, String) =
    "../rad_ffi.mjs" "rename"
}

/// TODO
///
pub fn which_rad() -> String {
  let or_try = fn(first, executable) {
    result.lazy_or(
      first,
      fn() {
        let rad =
          [rad_path, "/priv/", executable]
          |> string.concat
        ["--version"]
        |> shellout.command(run: rad, in: ".", opt: [])
        |> result.replace(rad)
        |> result.nil_error
      },
    )
  }

  assert Ok(path) =
    "rad"
    |> shellout.which
    |> result.nil_error
    |> or_try("rad")
    |> or_try("rad.ps1")
  path
}

/// TODO
///
pub fn working_directory() -> Result(String, Snag) {
  do_working_directory()
  |> result.replace_error(snag.new("failed to get current working directory"))
}

if erlang {
  external fn do_working_directory() -> Result(String, file.Reason) =
    "file" "get_cwd"
}

if javascript {
  external fn do_working_directory() -> Result(String, Nil) =
    "../rad_ffi.mjs" "working_directory"
}
