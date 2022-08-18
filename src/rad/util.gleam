//// A motley assortment of utility functions.
////

import gleam/dynamic.{Dynamic}
import gleam/float
import gleam/function
import gleam/int
import gleam/io
import gleam/list
import gleam/map
import gleam/result
import gleam/string
import gleam/string_builder
import glint.{CommandInput}
import glint/flag
import shellout.{CommandOpt, LetBeStderr, LetBeStdout, Lookups}
import snag.{Snag}

if erlang {
  import gleam/erlang/atom
  import gleam/erlang/file.{Enoent}
}

/// Custom color [`Lookups`](https://hexdocs.pm/shellout/shellout.html#Lookups)
/// for `rad`.
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

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Runtime Functions                      //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

/// The base path for `rad`'s compiled JavaScript modules.
///
pub const rad_path = "./build/dev/javascript/rad"

/// Runs Erlang with the given arguments and shellout
/// [`CommandOpt`](https://hexdocs.pm/shellout/shellout.html#CommandOpt)s. All
/// dependency and project modules are preloaded and accessible.
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

/// Results in a list of paths comprising all compiled Erlang modules for a
/// project and its dependencies on success, or `Nil` on failure.
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

/// Runs Node.js with the given arguments and shellout
/// [`CommandOpt`](https://hexdocs.pm/shellout/shellout.html#CommandOpt)s. All
/// dependency and project modules are preloaded and accessible.
///
pub fn javascript_run(
  with args: List(String),
  opt options: List(CommandOpt),
) -> Result(String, Snag) {
  ["--experimental-fetch", "--experimental-repl-await", "--no-warnings", ..args]
  |> shellout.command(run: "node", in: ".", opt: options)
  |> result.replace_error(snag.new("failed to run `node`"))
}

/// Results in an error meant to notify users that a [`Task`](task.html#Task)
/// cannot be carried out using the Erlang runtime.
///
pub fn refuse_erlang() -> Result(String, Snag) {
  "task cannot be run with erlang"
  |> snag.error
  |> snag.context("failed to run task")
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// File System Functions                  //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

/// Returns a boolean indicating whether or not a file exists at the given
/// `path`.
///
pub fn file_exists(path: String) -> Bool {
  do_file_exists(path)
}

if erlang {
  fn do_file_exists(path: String) -> Bool {
    // TODO when gleam_erlang changes: file.exists(path)
    file.is_file(path)
  }
}

if javascript {
  external fn do_file_exists(String) -> Bool =
    "" "globalThis.fs.existsSync"
}

/// Tries to write some `contents` to a file at the given `path`.
///
/// Results in an empty string on success, or a
/// [`Snag`](https://hexdocs.pm/snag/snag.html#Snag) on failure.
///
pub fn file_write(
  contents contents: String,
  to path: String,
) -> Result(String, Snag) {
  contents
  |> do_file_write(path)
  |> result.replace("")
  |> result.map_error(with: fn(_reason) {
    ["failed to write to `", path, "`"]
    |> string.concat
    |> snag.new
  })
}

if erlang {
  fn do_file_write(contents: String, path: String) -> Result(Nil, file.Reason) {
    file.write(contents: contents, to: path)
  }
}

if javascript {
  external fn do_file_write(String, String) -> Result(Nil, Dynamic) =
    "../rad_ffi.mjs" "file_write"
}

/// Returns a boolean indicating whether or not a directory exists at the given
/// `path`.
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

/// Tries to create a new directory at the given `path`.
///
/// No attempt is made to create any missing parent directories.
///
/// Results in an empty string on success, or a
/// [`Snag`](https://hexdocs.pm/snag/snag.html#Snag) on failure.
///
pub fn make_directory(path: String) -> Result(String, Snag) {
  path
  |> do_make_directory
  |> result.replace("")
  |> result.map_error(with: fn(_reason) {
    ["failed to make directory `", path, "`"]
    |> string.concat
    |> snag.new
  })
}

if erlang {
  fn do_make_directory(path: String) -> Result(Nil, file.Reason) {
    file.make_directory(path)
  }
}

if javascript {
  external fn do_make_directory(String) -> Result(Nil, String) =
    "../rad_ffi.mjs" "make_directory"
}

/// Tries to recursively delete the given `path`.
///
/// If the `path` is a directory, it will be deleted along with all of its
/// contents.
///
/// Results in an empty string on success, or a
/// [`Snag`](https://hexdocs.pm/snag/snag.html#Snag) on failure.
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
    case file.recursive_delete(path) {
      Error(Enoent) -> Ok(Nil)
      result -> result
    }
  }
}

if javascript {
  external fn do_recursive_delete(String) -> Result(Nil, String) =
    "../rad_ffi.mjs" "recursive_delete"
}

/// Tries to move a given `source` path to a new location.
///
/// Results in an empty string on success, or a
/// [`Snag`](https://hexdocs.pm/snag/snag.html#Snag) on failure.
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

/// Results in the current working directory path on success, or a
/// [`Snag`](https://hexdocs.pm/snag/snag.html#Snag) on failure.
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

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Miscellaneous Functions                //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

/// Returns a JSON string representation for any given data.
///
pub fn encode_json(data: a) -> String {
  do_encode_json(data)
}

if erlang {
  external fn do_encode_json(a) -> String =
    "thoas" "encode"
}

if javascript {
  external fn do_encode_json(a) -> String =
    "" "globalThis.JSON.stringify"
}

/// Turns a [`Snag`](https://hexdocs.pm/snag/snag.html#Snag) into a multiline
/// string optimized for readability.
///
pub fn snag_pretty_print(snag: Snag) -> String {
  let builder =
    [
      "error"
      |> bold(and: ["red"]),
      ": "
      |> bold([]),
      snag.issue
      |> bold([]),
      "\n",
    ]
    |> string_builder.from_strings

  case snag.cause {
    [] -> builder
    cause ->
      [
        "\n",
        "cause"
        |> bold(and: ["red"]),
        ":\n"
        |> bold([]),
      ]
      |> string_builder.from_strings
      |> string_builder.append_builder(to: builder)
      |> string_builder.append_builder(suffix: pretty_print_cause(cause))
  }
  |> string_builder.to_string
}

fn pretty_print_cause(cause) {
  cause
  |> list.index_map(with: fn(index, line) {
    [
      "  ",
      index
      |> int.to_string
      |> bold(and: ["red"]),
      ": "
      |> bold([]),
      line
      |> bold([]),
      "\n",
    ]
    |> string.concat
  })
  |> string_builder.from_strings
}

fn bold(string, and colors: List(String)) -> String {
  string
  |> shellout.style(
    with: shellout.display(["bold"])
    |> map.merge(from: shellout.color(colors)),
    custom: lookups,
  )
}

/// Reconstructs a list of strings from a processed flag
/// [`Map`](https://hexdocs.pm/glint/glint/flag.html#Map).
///
/// Useful for relaying the processed flags from a
/// [`CommandInput`](https://hexdocs.pm/glint/glint.html#CommandInput) to a new
/// process.
///
pub fn relay_flags(flags: flag.Map) -> List(String) {
  flags
  |> map.delete(delete: test_flag)
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

/// Returns the path of a runnable `rad` invocation script.
///
pub fn which_rad() -> String {
  let or_try = fn(first, executable) {
    first
    |> result.lazy_or(fn() {
      let rad =
        [rad_path, "/priv/", executable]
        |> string.concat
      ["--version"]
      |> shellout.command(run: rad, in: ".", opt: [])
      |> result.replace(rad)
      |> result.nil_error
    })
  }

  assert Ok(path) =
    "rad"
    |> shellout.which
    |> result.nil_error
    |> or_try("rad")
    |> or_try("rad.ps1")
  path
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Test Support Functions                 //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

const test_flag = "rad-test"

//pub fn delete_test_flag(input: CommandInput) -> CommandInput {
//  let flags =
//    test_flag
//    |> map.delete(from: input.flags)
//  CommandInput(..input, flags: flags)
//}

/// Removes from the given `input` a flag specific to running `rad`'s unit
/// tests.
///
/// Returns a function that does nothing if `rad`'s test flag is present in the
/// given `input`, otherwise
/// [`io.print`](https://hexdocs.pm/gleam_stdlib/gleam/io.html#print).
///
/// Useful for suppressing output while running `rad`'s unit tests.
///
pub fn quiet_or_print(input: CommandInput) -> fn(String) -> Nil {
  case is_test(input) {
    True -> function.constant(Nil)
    False -> io.print
  }
}

/// Returns a function that does nothing if `rad`'s test flag is present in the
/// given `input`, otherwise
/// [`io.println`](https://hexdocs.pm/gleam_stdlib/gleam/io.html#println).
///
/// Useful for suppressing output while running `rad`'s unit tests.
///
pub fn quiet_or_println(input: CommandInput) -> fn(String) -> Nil {
  case is_test(input) {
    True -> function.constant(Nil)
    False -> io.println
  }
}

/// Instructs a
/// [`shellout.command`](https://hexdocs.pm/shellout/shellout.html#command) to
/// capture all output if `rad`'s test flag is present in the given `input`,
/// otherwise spawns the subprocess with stdout and stderr piped to its parent.
///
/// Useful for suppressing output while running `rad`'s unit tests.
///
pub fn quiet_or_spawn(input: CommandInput) -> List(CommandOpt) {
  case is_test(input) {
    True -> []
    False -> [LetBeStderr, LetBeStdout]
  }
}

fn is_test(input: CommandInput) -> Bool {
  let result =
    test_flag
    |> flag.get_value(from: input.flags)
  case result {
    Ok(flag.B(test)) -> test
    _else -> False
  }
}
