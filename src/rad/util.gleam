//// TODO
////

import gleam/dynamic.{Dynamic}
import gleam/function
import gleam/list
import gleam/result
import gleam/string
import shellout.{LetBeStderr, LetBeStdout}
import snag.{Snag}

if erlang {
  import gleam/erlang/file
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
pub fn packages(path: List(String)) -> Result(String, Snag) {
  toml(read: "build/packages/packages.toml", get: ["packages", ..path])
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

/// TODO
///
pub fn erlang_run(args: List(String)) -> Result(String, Snag) {
  ebin_paths()
  |> result.replace_error(snag.new("failed to find `ebin` paths"))
  |> result.then(apply: fn(ebins) {
    [["-pa", ..ebins], args]
    |> list.flatten
    |> shellout.command(
      run: "erl",
      with: _,
      in: ".",
      opt: [LetBeStderr, LetBeStdout],
    )
    |> result.replace_error(snag.new("failed to run `erl`"))
  })
}

/// TODO
///
pub fn javascript_run(args: List(String)) -> Result(String, Snag) {
  shellout.command(
    run: "node",
    with: ["--experimental-repl-await", "--no-deprecation", ..args],
    in: ".",
    opt: [LetBeStderr, LetBeStdout],
  )
  |> result.replace_error(snag.new("failed to run `node`"))
}
