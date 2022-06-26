//// TODO
////

import gleam/dynamic.{Dynamic}
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
import shellout.{CommandOpt, StyleFlags}
import snag.{Snag}

if erlang {
  import gleam/erlang/file
  import gleam/http/request
  import gleam/httpc
}

if javascript {
  import gleam/json
}

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
      ["dependency `", string.join(args, "."), "` not found"]
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
    file.list_directory(prefix)
    |> result.map(with: list.map(_, with: fn(subdirectory) {
      string.join([prefix, subdirectory, "ebin"], with: "/")
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
    |> shellout.command(run: "erl", with: _, in: ".", opt: options)
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
  shellout.command(
    run: "node",
    with: [
      "--experimental-fetch",
      "--experimental-repl-await",
      "--no-warnings",
      ..args
    ],
    in: ".",
    opt: options,
  )
  |> result.replace_error(snag.new("failed to run `node`"))
}

/// TODO
///
pub fn packages(path: List(String)) -> Result(String, Snag) {
  toml(read: "build/packages/packages.toml", get: ["packages", ..path])
}

/// TODO
///
pub fn ping(uri_string: String) -> Result(Int, Int) {
  assert Ok(uri) = uri.parse(uri_string)
  case uri.host {
    Some("localhost") -> Uri(..uri, host: Some("127.0.0.1"))
    _host -> uri
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

    [
      "--experimental-fetch",
      "--no-warnings",
      "--eval",
      [
        ["fetch('", uri_string, "', ", headers, ")"]
        |> string.concat,
        ".then((response) => response.status)",
        ".catch(() => 503)",
        ".then(console.log)",
        ".then(() => process.exit(0))",
      ]
      |> string.concat,
    ]
    |> javascript_run(opt: [])
    |> result.replace_error(503)
    |> result.then(apply: fn(status) {
      assert Ok(status) =
        status
        |> string.trim
        |> int.parse
      case status < 400 {
        True -> Ok(status)
        False -> Error(status)
      }
    })
  }
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
      _flag -> Error(Nil)
    }
  })
}

/// Results in an error meant to notify users that a task cannot be carried out
/// using the Erlang runtime.
///
pub fn refuse_erlang() -> Result(String, Snag) {
  snag.error("task cannot be run with erlang")
  |> snag.context("failed to run task")
}

/// Filters the style flags from a `glint.CommandInput.flags` record and
/// converts the map into a `shellout.StyleFlags` map.
///
pub fn style_flags(flags: flag.Map) -> StyleFlags {
  flags
  |> map.filter(for: fn(_key, contents) {
    let flag.Contents(value: value, ..) = contents
    case value {
      flag.LS(_strings) -> True
      _flag -> False
    }
  })
  |> map.map_values(with: fn(_key, contents) {
    let flag.Contents(value: value, ..) = contents
    assert flag.LS(value) = value
    value
  })
}

/// TODO
///
pub fn toml(
  read file: String,
  get key_path: List(String),
) -> Result(String, Snag) {
  case key_path == [] {
    False ->
      toml_read_file(file)
      |> result.replace_error(snag.new(string.concat([
        "failed to read `",
        file,
        "`",
      ])))
      |> result.then(apply: function.compose(
        toml_get(_, key_path),
        result.replace_error(_, snag.new("key not found")),
      ))
      |> result.then(apply: function.compose(
        dynamic.string,
        result.replace_error(_, snag.new("value is not a string")),
      ))
    True -> snag.error("key path not provided")
  }
}

/// TODO
///
pub fn toml_get(parsed: Dynamic, key_path: List(String)) -> Result(Dynamic, Nil) {
  do_toml_get(parsed, key_path)
}

if erlang {
  fn do_toml_get(
    parsed: Dynamic,
    key_path: List(String),
  ) -> Result(Dynamic, Nil) {
    parsed
    |> erlang_toml_get(key_path)
    |> result.nil_error
  }

  external fn erlang_toml_get(Dynamic, List(String)) -> Result(Dynamic, Dynamic) =
    "tomerl" "get"
}

if javascript {
  external fn do_toml_get(Dynamic, List(String)) -> Result(Dynamic, Nil) =
    "../rad_ffi.mjs" "toml_get"
}

/// TODO
///
pub fn toml_read_file(path: String) -> Result(Dynamic, Nil) {
  do_toml_read_file(path)
}

if erlang {
  fn do_toml_read_file(path: String) -> Result(Dynamic, Nil) {
    path
    |> erlang_toml_read_file
    |> result.nil_error
  }

  external fn erlang_toml_read_file(String) -> Result(Dynamic, Dynamic) =
    "tomerl" "read_file"
}

if javascript {
  external fn do_toml_read_file(String) -> Result(Dynamic, Nil) =
    "../rad_ffi.mjs" "toml_read_file"
}

/// TODO
///
pub fn which_rad() -> String {
  let or_try = fn(first, executable) {
    result.lazy_or(
      first,
      fn() {
        let rad = string.concat([rad_path, "/priv/", executable])
        shellout.command(run: rad, with: ["--version"], in: ".", opt: [])
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
  // TODO: unify erlang and js file.reason errors instead of uninformative snag?
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
