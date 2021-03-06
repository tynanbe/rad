//// The standard `rad` workbook module exemplifies how to create a custom
//// `workbook.gleam` module for your own project.
////
//// By providing [`main`](#main) and [`workbook`](#workbook) functions in your
//// project's `workbook.gleam` file, you can extend `rad`'s standard
//// [`workbook`](#workbook) with your own or write one entirely from scratch,
//// optionally making it and your [`Runner`](../task.html#Runner)s available
//// for any dependent projects!
////
//// All [`Runner`](../task.html#Runner) functions return the
//// [`task.Result`](../task.html#Result) type, which is a `String` on success
//// or a [`Snag`](https://hexdocs.pm/snag/snag.html#Snag) on failure. As such,
//// this documentation describes the side effects of the standard
//// [`workbook`](#workbook)'s runners, whether they occur in another
//// [`Runner`](../task.html#Runner) or [`rad.do_main`](../../rad.html#do_main)
//// (either of which might print a non-empty [`Result`](../task.html#Result)),
//// or directly.
////

import gleam
import gleam/dynamic
import gleam/function
import gleam/http.{Header}
import gleam/int
import gleam/io
import gleam/list
import gleam/map
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/uri.{Uri}
import glint.{CommandInput}
import glint/flag
import rad
import rad/task.{
  Parsed, Result, Task, arguments, delimit, flag, flags, for, formatters, gleam,
  new, or, packages, parameter, shortdoc, targets, with_config, with_manifest,
}
import rad/toml.{Toml}
import rad/util
import rad/workbook.{Workbook, help, task}
import shellout.{LetBeStderr, LetBeStdout, StyleFlags}
import snag.{Snag}

if erlang {
  import gleam/http/request
  import gleam/httpc
}

if javascript {
  import gleam/json
}

/// Directories that are omitted when printing, watching, etc.
///
pub const ignore_glob = ".git|_build|build|deps|node_modules"

/// Runs [`rad.do_main`](../../rad.html#do_main) with `rad`'s standard
/// [`workbook`](#workbook).
///
/// You can use your project's `gleam.toml` config to have `rad` run your own
/// `workbook.gleam` module's `main` function. Similar to importing a Gleam
/// module, the path is relative to the module's `src` directory and should omit
/// the `.gleam` extension.
///
/// ## Examples
///
/// ```toml
/// [rad]
/// workbook = "my/workbook"
/// ```
///
/// Note that `rad`'s standard workbook module is run by default, with no config
/// necessary.
///
pub fn main() -> Nil {
  workbook()
  |> rad.do_main
}

/// Returns `rad`'s standard [`Workbook`](../workbook.html#Workbook), which can
/// be used as a base when building your own.
///
pub fn workbook() -> Workbook {
  let style_flags = [
    flag.strings(
      called: "display",
      default: ["bold"],
      explained: "Set display styles",
    ),
    flag.strings(
      called: "color",
      default: ["pink"],
      explained: "Set a foreground color",
    ),
    flag.strings(
      called: "background",
      default: [],
      explained: "Set a background color",
    ),
  ]

  let toml =
    "gleam.toml"
    |> toml.parse_file
    |> result.lazy_unwrap(or: toml.new)

  let target_flags = [
    ["rad", "targets"]
    // TODO: swap for gleam_stdlib > 0.22.1
    //|> toml.decode(from: toml, expect: dynamic.list(of: dynamic.string))
    |> toml.decode(from: toml, expect: dynamic_list(of: dynamic.string))
    |> result.lazy_or(fn() {
      ["target"]
      |> toml.decode(from: toml, expect: dynamic.string)
      |> result.map(with: fn(target) { [target] })
    })
    |> result.unwrap(or: ["erlang"])
    |> flag.strings(called: "target", explained: "The platforms to target"),
  ]

  let package_flags = [
    flag.bool(
      called: "all",
      default: False,
      explained: "Run the task for all packages",
    ),
  ]

  let watch_flags = [
    flag.bool(
      called: "no-docs",
      default: False,
      explained: "Disable docs handling",
    ),
    flag.int(
      called: "port",
      default: 7000,
      explained: "Request live reloads over port (default 7000)",
    ),
    ..target_flags
  ]

  workbook.new()
  |> task(
    add: []
    |> new(run: root)
    |> flag(
      called: "version",
      explained: "Print rad's version",
      expect: flag.bool,
      default: False,
    )
    |> with_config,
  )
  |> task(
    add: ["add"]
    |> new(run: gleam(["add"]))
    |> shortdoc("Add new project dependencies")
    |> flag(
      called: "dev",
      explained: "Add the packages as dev-only dependencies",
      expect: flag.bool,
      default: False,
    )
    |> parameter(with: "..<packages>", of: "Names of Hex packages"),
  )
  |> task(
    add: ["build"]
    |> new(run: gleam(["build"]))
    |> for(each: targets)
    |> shortdoc("Build the project")
    |> flag(
      called: "warnings-as-errors",
      explained: "Emit compile time warnings as errors",
      expect: flag.bool,
      default: False,
    )
    |> flags(add: target_flags),
  )
  |> task(
    add: ["check"]
    |> new(run: gleam(["check"]))
    |> shortdoc("Type check the project"),
  )
  |> task(
    add: ["clean"]
    |> new(run: gleam(["clean"]))
    |> shortdoc("Clean build artifacts"),
  )
  |> task(
    add: ["config"]
    |> new(run: config)
    |> shortdoc("Print project config values")
    |> parameter(with: "<path>", of: "TOML breadcrumbs, space-separated")
    |> with_config,
  )
  |> task(
    add: ["deps"]
    |> new(run: help(from: workbook))
    |> shortdoc("Work with dependency packages")
    |> with_config,
  )
  |> task(
    add: ["deps", "list"]
    |> new(run: gleam(["deps", "list"]))
    |> shortdoc("List dependency packages"),
  )
  |> task(
    add: ["deps", "update"]
    |> new(run: gleam(["deps", "update"]))
    |> shortdoc("Update dependency packages"),
  )
  |> task(
    add: ["docs"]
    |> new(run: help(from: workbook))
    |> shortdoc("Work with HTML documentation")
    |> with_config,
  )
  |> task(
    add: ["docs", "build"]
    |> new(run: docs_build)
    |> for(
      each: packages
      |> or(cond: "all", else: arguments),
    )
    |> shortdoc("Render HTML documentation")
    |> flags(add: package_flags)
    |> parameter(
      with: "..[packages]",
      of: "Package names (default: current project)",
    )
    |> with_config,
  )
  |> task(
    add: ["docs", "serve"]
    |> new(run: docs_serve)
    |> shortdoc("Serve HTML documentation")
    |> flag(
      called: "host",
      explained: "Bind to host (default localhost)",
      expect: flag.string,
      default: "localhost",
    )
    |> flag(
      called: "no-live",
      explained: "Disable live reloading",
      expect: flag.bool,
      default: False,
    )
    |> flag(
      called: "port",
      explained: "Listen on port (default 7000)",
      expect: flag.int,
      default: 7000,
    )
    |> flags(add: package_flags)
    |> parameter(
      with: "..[packages]",
      of: "Package names to build docs for (default: current project)",
    )
    |> with_config,
  )
  |> task(
    add: ["format"]
    |> new(run: format)
    |> for(each: formatters)
    |> delimit(with: "\n\n")
    |> shortdoc("Format source code")
    |> flag(
      called: "check",
      explained: "Check if inputs are formatted without changing them",
      expect: flag.bool,
      default: False,
    )
    |> flag(called: "fail", explained: "", expect: flag.bool, default: False),
  )
  //|> parameter(with: "..[files]", of: "Files to format (default: .)"),
  |> task(
    add: ["Hello,", "Lucy!"]
    |> new(run: hello_lucy)
    |> flags(add: list.drop(from: style_flags, up_to: 1))
    |> shortdoc("Greet Gleam's mascot ✨"),
  )
  |> task(
    add: ["help"]
    |> new(run: help(from: workbook))
    |> shortdoc("Print help information")
    |> parameter(
      with: "[subcommand]",
      of: "Subcommand breadcrumbs, space-separated",
    )
    |> with_config,
  )
  |> task(
    add: ["name"]
    |> new(run: name)
    |> for(
      each: packages
      |> or(cond: "all", else: arguments),
    )
    |> shortdoc("Print package names")
    |> flags(add: package_flags)
    |> flags(add: style_flags)
    |> parameter(
      with: "..[packages]",
      of: "Package names (default: current project)",
    )
    |> with_config,
  )
  |> task(
    add: ["origin"]
    |> new(run: origin)
    |> shortdoc("Print the repository URL"),
  )
  |> task(
    add: ["ping"]
    |> new(run: ping)
    |> for(each: arguments)
    |> shortdoc("Fetch HTTP status codes")
    |> parameter(with: "..<uris>", of: "Request locations"),
  )
  |> task(
    add: ["shell"]
    |> new(run: shell)
    |> shortdoc("Start a shell")
    |> parameter(
      with: "[runtime]",
      of: "Runtime name or alias (default: erl; options: deno, erl, iex, node)",
    )
    |> with_config,
  )
  |> task(
    add: ["test"]
    |> new(run: gleam(["test"]))
    |> for(each: targets)
    |> shortdoc("Run the project tests")
    |> flags(add: target_flags),
  )
  |> task(
    add: ["tree"]
    |> new(run: tree)
    |> shortdoc("Print the file structure"),
  )
  |> task(
    add: ["version"]
    |> new(run: version)
    |> for(
      each: packages
      |> or(cond: "all", else: arguments),
    )
    |> shortdoc("Print package versions")
    |> flags(add: package_flags)
    |> flag(
      called: "bare",
      explained: "Omit package names",
      expect: flag.bool,
      default: False,
    )
    |> flags(add: style_flags)
    |> parameter(
      with: "..[packages]",
      of: "Package names (default: current project)",
    )
    |> with_config
    |> with_manifest,
  )
  |> task(
    add: ["watch"]
    |> new(run: watch)
    |> shortdoc("Automate project tasks")
    |> flags(add: watch_flags),
  )
  |> task(
    add: ["watch", "do"]
    |> new(run: watch_do)
    |> flags(add: watch_flags),
  )
}

/// Prints [`help`](../workbook.html#help) information, or `rad`'s version when
/// given the `--version` flag.
///
pub fn root(input: CommandInput, task: Task(Result)) -> Result {
  assert Ok(flag.B(ver)) =
    "version"
    |> flag.get_value(from: input.flags)
  case ver {
    True -> {
      let flags =
        [#("bare", flag.Contents(value: flag.B(False), description: ""))]
        |> flag.build_map
      let version = fn(args) {
        args
        |> CommandInput(flags: flags)
        |> version(task)
      }
      ["rad"]
      |> version
      |> result.lazy_or(fn() { version([]) })
    }
    False ->
      input
      |> workbook.help(from: workbook)(task)
  }
}

/// Prints project configuration values from `gleam.toml` as stringified JSON.
///
/// Input arguments are taken to be a breadcrumb trail of TOML keys, and a
/// subset of the configuration is printed upon successful traversal.
///
pub fn config(input: CommandInput, task: Task(Result)) -> Result {
  assert Parsed(config) = task.config
  input.args
  |> toml.decode(from: config, expect: dynamic.dynamic)
  |> result.map(with: util.encode_json)
}

/// Renders HTML documentation for local Gleam packages.
///
/// Any number of packages, or `--all`, can be given as input arguments; if none
/// are given, the current project's documentation is rendered.
///
pub fn docs_build(input: CommandInput, task: Task(Result)) -> Result {
  assert Ok(flag.B(all)) =
    "all"
    |> flag.get_value(from: input.flags)

  try #(name, is_self) =
    self_or_dependency(
      input,
      task,
      self: fn(self, _config) { Ok(self) },
      or: fn(config) {
        case all {
          True ->
            input.args
            |> list.first
            |> result.replace_error(snag.new("no package found"))
          False ->
            input.args
            |> dependency_name(from: config)
        }
      },
    )

  let path = case is_self {
    True -> "."
    False ->
      ["./build/packages/", name]
      |> string.concat
  }

  let is_gleam =
    [path, "/gleam.toml"]
    |> string.concat
    |> util.file_exists

  case is_gleam {
    True ->
      ["docs", "build"]
      |> shellout.command(
        run: "gleam",
        in: path,
        opt: [LetBeStderr, LetBeStdout],
      )
      |> result.replace_error(snag.new("failed building docs"))
      |> result.then(apply: fn(_output) {
        case is_self {
          True -> Ok("")
          False -> {
            let docs_dir = "./build/dev/docs/"
            try _result = case util.is_directory(docs_dir) {
              True -> Ok("")
              False -> util.make_directory(docs_dir)
            }
            let new_path =
              [docs_dir, name]
              |> string.concat
            try _result =
              new_path
              |> util.recursive_delete
            [path, "/build/dev/docs/", name]
            |> string.concat
            |> util.rename(to: new_path)
          }
        }
      })
    False if all -> {
      let _print =
        [
          "   Skipping"
          |> shellout.style(with: shellout.color(["magenta"]), custom: []),
          name,
        ]
        |> string.join(with: " ")
        |> io.println
      let _print =
        [
          "",
          "No gleam.toml file was found in",
          [path, "/"]
          |> string.concat,
        ]
        |> string.join(with: "\n")
        |> io.println
      Ok("")
    }
    _else ->
      ["`", name, "` is not a Gleam package\n"]
      |> string.concat
      |> snag.error
  }
}

/// Serves HTML documentation for local Gleam packages.
///
/// Any number of packages, or `--all`, can be given as input arguments to
/// render before serving; if none are given, the current project's
/// documentation is rendered.
///
/// The `build/dev/docs/` directory is by default served at [http://localhost:7000/](http://localhost:7000/) with support for live reloading. Host, port, and live reloading support can all be altered via input flags. For example, setting `--host=0.0.0.0` allows the server to respond to external requests.
///
pub fn docs_serve(input: CommandInput, task: Task(Result)) -> Result {
  try _output = docs_build(input, task)

  io.println("")

  assert Ok(flag.S(host)) =
    "host"
    |> flag.get_value(from: input.flags)
  assert Ok(flags) = case host {
    "localhost" ->
      "--host=127.0.0.1"
      |> flag.update_flags(in: input.flags)
    _else -> Ok(input.flags)
  }

  [
    [
      [util.rad_path, "/priv/node_modules/wonton/src/bin.js"]
      |> string.concat,
    ],
    util.relay_flags(flags),
    ["--", "./build/dev/docs"],
  ]
  |> list.flatten
  |> util.javascript_run(opt: [LetBeStderr, LetBeStdout])
  |> result.replace("")
}

/// Formats your project's source code, or verifies that it has already been
/// formatted when given the `--check` flag.
///
/// Gleam code in the `src` and `test` directories, and any of their
/// subdirectories, is formatted by default.
///
/// Additional [`Formatter`](../task.html#Formatter)s can be defined in your
/// project's `gleam.toml` configuration file.
///
/// ## Examples
///
/// ```toml
/// [[rad.formatters]]
/// name = "javascript"
/// check = ["rome", "ci", "--indent-style=space", "src", "test"]
/// run = ["rome", "format", "--indent-style=space", "--write", "src", "test"]
/// ```
///
/// All valid [`Formatter`](../task.html#Formatter)s are run or checked in
/// sequence regardless of any errors along the way, but they must all be valid
/// and successful for this [`Runner`](../task.html#Runner) to succeed.
///
pub fn format(input: CommandInput, task: Task(Result)) -> Result {
  assert Ok(flag.B(fail)) =
    "fail"
    |> flag.get_value(from: input.flags)
  try _result = case fail {
    True -> snag.error("invalid formatter in `gleam.toml`")
    False -> Ok("")
  }

  try result =
    map.new()
    |> CommandInput(args: [])
    |> task.basic(input.args)(task)
    |> result.map_error(with: fn(_snag) {
      assert Ok(flag.B(check)) =
        "check"
        |> flag.get_value(from: input.flags)
      case check {
        True -> "failed format check"
        False -> "failed formatting"
      }
      |> snag.new
    })

  let [command, ..] = input.args
  assert Ok(flag.B(check)) =
    "check"
    |> flag.get_value(from: input.flags)
  let action = case check {
    True -> "Checked"
    False -> "Formatted"
  }
  case command {
    "gleam" ->
      [action, "all files in `src` and `test`"]
      |> string.join(with: " ")
      |> Ok
    _else -> Ok(result)
  }
}

/// Prints stylized names for packages found in your project's `gleam.toml`
/// configuration file.
///
/// Any number of packages, or `--all`, can be given as input arguments; if none
/// are given, the current project's name is printed.
///
/// The style can be set with the `--display`, `--color`, and `--background`
/// flags, which are passed to
/// [`shellout.style`](https://hexdocs.pm/shellout/shellout.html#style).
///
/// Can be useful as a building block in other [`Runner`](../task.html#Runner)s.
///
pub fn name(input: CommandInput, task: Task(Result)) -> Result {
  try #(name, _is_self) =
    self_or_dependency(
      input,
      task,
      self: fn(self, _config) { Ok(self) },
      or: dependency_name(input.args, from: _),
    )

  name
  |> shellout.style(with: style_flags(input.flags), custom: util.lookups)
  |> Ok
}

/// Filters the flags from a
/// [`CommandInput`](https://hexdocs.pm/glint/glint.html#CommandInput) record
/// and converts the map into a
/// [`StyleFlags`](https://hexdocs.pm/shellout/shellout.html#StyleFlags) map.
///
fn style_flags(flags: flag.Map) -> StyleFlags {
  flags
  |> map.filter(for: fn(_key, contents) {
    let flag.Contents(value: value, ..) = contents
    case value {
      flag.LS(_strings) -> True
      _else -> False
    }
  })
  |> map.map_values(with: fn(_key, contents) {
    let flag.Contents(value: value, ..) = contents
    assert flag.LS(value) = value
    value
  })
}

/// Prints the repository URL for the `git` remote named origin.
///
/// Requires the `git` command to be available on the system.
///
pub fn origin(_input: CommandInput, _task: Task(Result)) -> Result {
  ["remote", "get-url", "origin"]
  |> shellout.command(run: "git", in: ".", opt: [])
  |> result.replace_error(snag.new("git remote `origin` not found"))
}

/// Fetches the HTTP status codes for the given URIs.
///
/// All URIs are checked in sequence regardless of any errors along the way, but
/// all status codes must be successful for this [`Runner`](../task.html#Runner)
/// to succeed.
///
pub fn ping(input: CommandInput, _task: Task(Result)) -> Result {
  try uri_string = case input.args {
    [uri_string, ..] -> Ok(uri_string)
    _else -> snag.error("URI not provided")
  }
  try uri =
    uri_string
    |> uri.parse
    |> result.map_error(with: fn(_nil) {
      ["invalid URI `", uri_string, "`"]
      |> string.concat
      |> snag.new
    })
  case uri.host {
    Some("localhost") -> Uri(..uri, host: Some("127.0.0.1"))
    _else -> uri
  }
  |> uri.to_string
  |> do_ping([#("cache-control", "no-cache, no-store")])
  |> result.map(with: int.to_string)
  |> result.map_error(
    with: int.to_string
    |> function.compose(snag.new),
  )
}

if erlang {
  fn do_ping(
    uri_string: String,
    headers: List(Header),
  ) -> gleam.Result(Int, Int) {
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
  fn do_ping(
    uri_string: String,
    headers: List(Header),
  ) -> gleam.Result(Int, Int) {
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
      |> util.javascript_run(opt: [])
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

/// Launches an interactive shell, or REPL, with all of your project's modules
/// and dependencies preloaded and available.
///
/// The input argument specifies the type of shell to run, defaulting to `erl`,
/// the Erlang shell, if none is given. Valid shells include `deno`, `erl` (or
/// `erlang`), `iex` (or `elixir`), and `node` (or `nodejs`).
///
/// The syntax for accessing modules depends on the chosen shell.
///
/// ## Erlang
///
/// ```erlang
/// 1> gleam@io:println("Hi from Erlang").
/// Hi from Erlang
/// nil
/// ```
///
/// ## Elixir
///
/// ```elixir
/// iex(1)> :gleam@io.println("Hi from Elixir")
/// Hi from Elixir
/// nil
/// ```
///
/// ## JavaScript
///
/// ```javascript
/// > $gleam$io.println("Hi from JavaScript")
/// Hi from JavaScript
/// undefined
/// ```
///
pub fn shell(input: CommandInput, task: Task(Result)) -> Result {
  do_shell(input, task)
}

if erlang {
  fn do_shell(_input: CommandInput, _task: Task(Result)) -> Result {
    util.refuse_erlang()
  }
}

if javascript {
  fn do_shell(input: CommandInput, task: Task(Result)) -> Result {
    let options = [LetBeStderr, LetBeStdout]
    let runtime = case input.args {
      [runtime, ..] -> runtime
      _else -> "erlang"
    }
    let javascript =
      [
        ["import('", util.rad_path, "/dist/rad_ffi.mjs", "')"],
        [".then(module => module.load_modules())"],
      ]
      |> list.flatten
      |> string.concat

    case runtime {
      "elixir" | "iex" -> {
        assert Parsed(config) = task.config
        try name =
          ["name"]
          |> toml.decode(from: config, expect: dynamic.string)
        try ebins =
          util.ebin_paths()
          |> result.replace_error(snag.new("failed to find `ebin` paths"))
        [
          ["--app", name],
          [
            "--erl",
            ["-pa", ..ebins]
            |> string.join(with: " "),
          ],
        ]
        |> list.flatten
        |> shellout.command(run: "iex", in: ".", opt: options)
        |> result.replace_error(snag.new("failed to run `iex` shell"))
      }

      "erlang" | "erl" ->
        []
        |> util.erlang_run(opt: options)

      "deno" ->
        ["repl", "--compat", "--unstable", "--eval", javascript]
        |> shellout.command(run: "deno", in: ".", opt: options)
        |> result.replace_error(snag.new("failed to run `deno` shell"))

      "nodejs" | "node" ->
        ["--interactive", "--eval", javascript]
        |> util.javascript_run(opt: options)

      _else ->
        ["unsupported runtime `", runtime, "`"]
        |> string.concat
        |> snag.error
    }
  }
}

/// Prints your project's file structure using a tree representation.
///
/// Some paths, such as `.git` and `build` (see [`ignore_glob`](#ignore_glob)), are ignored.
///
/// Requires the `exa` or `tree` command to be available on the system, (in
/// order of preference).
///
/// When running `exa`, a `git` status summary is shown for each file.
///
pub fn tree(_input: CommandInput, _task: Task(Result)) -> Result {
  assert Ok(working_directory) = util.working_directory()
  let result =
    [
      "--all",
      "--color=always",
      "--git",
      "--git-ignore",
      ["--ignore-glob=", ignore_glob]
      |> string.concat,
      "--long",
      "--no-filesize",
      "--no-permissions",
      "--no-user",
      "--no-time",
      "--tree",
      working_directory,
    ]
    |> shellout.command(run: "exa", in: ".", opt: [])
    |> result.replace_error(snag.new("command `exa` not found"))
  case result {
    Ok(_output) -> result
    Error(error) ->
      [
        ["-a"],
        ["-C"],
        ["-I", ignore_glob],
        ["--matchdirs"],
        ["--noreport"],
        [working_directory],
      ]
      |> list.flatten
      |> shellout.command(run: "tree", in: ".", opt: [])
      |> result.replace_error(snag.layer(error, "command `tree` not found"))
  }
  |> result.map_error(with: function.compose(
    snag.layer(_, "failed to find a known tree command"),
    snag.layer(_, "failed to run task"),
  ))
}

/// Prints stylized versions for packages found in your project's `gleam.toml`
/// configuration file.
///
/// Any number of packages, or `--all`, can be given as input arguments; if none
/// are given, the current project's version is printed.
///
/// If the `--bare` flag is given, only the version strings are printed.
///
/// The style can be set with the `--display`, `--color`, and `--background`
/// flags, which are passed to
/// [`shellout.style`](https://hexdocs.pm/shellout/shellout.html#style).
///
pub fn version(input: CommandInput, task: Task(Result)) -> Result {
  assert Ok(flag.B(bare)) =
    "bare"
    |> flag.get_value(from: input.flags)

  try name = case bare {
    True -> Ok(None)
    False ->
      input
      |> name(task)
      |> result.map(with: Some)
  }

  try #(version, _is_self) =
    self_or_dependency(
      input,
      task,
      self: fn(_self, config) {
        ["version"]
        |> toml.decode(from: config, expect: dynamic.string)
      },
      or: fn(_config) {
        assert Parsed(manifest) = task.manifest
        ["packages"]
        // TODO: swap for gleam_stdlib > 0.22.1
        //|> toml.decode(from: manifest, expect: dynamic.list(of: toml.from_dynamic))
        |> toml.decode(
          from: manifest,
          expect: dynamic_list(of: toml.from_dynamic),
        )
        |> result.unwrap(or: [])
        |> list.find_map(with: fn(toml) {
          let decode = toml.decode(_, from: toml, expect: dynamic.string)
          try name = decode(["name"])
          case [name] == input.args {
            True -> decode(["version"])
            False -> snag.error("")
          }
        })
        |> result.map_error(with: fn(_nil) {
          let [name] = input.args
          ["dependency `", name, "` not found"]
          |> string.concat
          |> snag.new
        })
      },
    )

  let version =
    case bare {
      True -> version
      False ->
        ["v", version]
        |> string.concat
    }
    |> Some

  [name, version]
  |> option.values
  |> string.join(with: " ")
  |> Ok
}

/// Watches your project's files and runs commands when they change.
///
/// Some paths, such as `.git` and `build` (see [`ignore_glob`](#ignore_glob)),
/// are ignored.
///
/// Requires the `watchexec` or `inotifywait` command to be available on the
/// system (in order of preference).
///
/// Input arguments are taken to be a command to run when changes are detected.
/// If no arguments are given, the command defaults to
/// [`rad watch do`](#watch_do).
///
/// Note that `rad` makes few assumptions about the local environment and will
/// not run commands through any shell interpreter on its own. As such, one
/// method of running multiple commands is to wrap them in a single command that
/// invokes the shell interpreter of your choice.
///
/// ## Examples
///
/// ```shell
/// > rad watch sh -c \
///   'n() shuf -i99-156 -n1; clear; rad version --color=$(n),$(n),$(n)'
/// ```
///
pub fn watch(input: CommandInput, task: Task(Result)) -> Result {
  do_watch(input, task)
}

if erlang {
  fn do_watch(_input: CommandInput, _task: Task(Result)) -> Result {
    util.refuse_erlang()
  }
}

if javascript {
  fn do_watch(input: CommandInput, _task: Task(Result)) -> Result {
    let options = [LetBeStderr, LetBeStdout]
    let [command, ..args] as watch_do = case input.args {
      [] -> {
        let rad = util.which_rad()
        let flags = util.relay_flags(input.flags)
        [rad, "watch", "do", ..flags]
      }
      args -> args
    }

    [
      " Watching"
      |> shellout.style(with: shellout.color(["magenta"]), custom: util.lookups),
      " … "
      |> shellout.style(with: shellout.color(["cyan"]), custom: util.lookups),
      "(Ctrl+C to quit)",
    ]
    |> string.concat
    |> io.println

    let result =
      [
        ignore_glob
        |> string.split(on: "|")
        |> list.map(with: fn(directory) {
          ["--ignore=**/", directory, "/**"]
          |> string.concat
        }),
        ["--no-shell"],
        ["--postpone"],
        ["--watch-when-idle"],
        ["--", ..watch_do],
      ]
      |> list.flatten
      |> shellout.command(run: "watchexec", in: ".", opt: options)
      |> result.replace_error(snag.new("command `watchexec` not found"))
    case result {
      Ok(_output) -> result
      Error(error) ->
        watch_loop(
          on: fn() {
            [
              ["--event", "create"],
              ["--event", "delete"],
              ["--event", "modify"],
              ["--event", "move"],
              [
                "--exclude",
                ["^[./\\\\]*(", ignore_glob, ")([/\\\\].*)*$"]
                |> string.concat,
              ],
              ["-qq"],
              ["--recursive"],
              ["."],
            ]
            |> list.flatten
            |> shellout.command(run: "inotifywait", in: ".", opt: options)
          },
          do: fn() {
            command
            |> shellout.command(with: args, in: ".", opt: options)
          },
        )
        |> result.replace_error(snag.layer(
          error,
          "command `inotifywait` not found",
        ))
    }
    |> result.map_error(with: function.compose(
      snag.layer(_, "failed to find a known watcher command"),
      snag.layer(_, "failed to run task"),
    ))
  }

  external fn watch_loop(
    on: fn() -> gleam.Result(String, #(Int, String)),
    do: fn() -> gleam.Result(String, #(Int, String)),
  ) -> gleam.Result(String, Nil) =
    "../../rad_ffi.mjs" "watch_loop"
}

/// Runs several `rad` tasks in succession: renders the project's HTML
/// documentation, signals the documentation server to do a live reload for all
/// known client connections, and runs the project's tests for all specified
/// targets.
///
/// Accepts the `--no-docs`, `--port`, and `--target` input flags.
///
/// This is the default action when running [`rad watch`](#watch).
///
/// Note that default targets can also be specified in your project's
/// `gleam.toml` configuration file.
///
/// ## Examples
///
/// ```toml
/// [rad]
/// targets = ["erlang", "javascript"]
/// ```
///
pub fn watch_do(input: CommandInput, _task: Task(Result)) -> Result {
  assert Ok(flag.B(no_docs)) =
    "no-docs"
    |> flag.get_value(from: input.flags)
  assert Ok(flag.I(port)) =
    "port"
    |> flag.get_value(from: input.flags)
  assert Ok(target_flag) =
    "target"
    |> map.get(input.flags, _)

  io.println("")

  case no_docs {
    True -> Nil
    False -> {
      [
        " Generating"
        |> shellout.style(
          with: shellout.color(["magenta"]),
          custom: util.lookups,
        ),
        "documentation",
      ]
      |> string.join(with: " ")
      |> io.println
      let _result =
        ["docs", "build"]
        |> shellout.command(run: "gleam", in: ".", opt: [])
      // Live reload docs
      let uri_string =
        ["http://localhost:", int.to_string(port), "/wonton-update"]
        |> string.concat
      let _result =
        [uri_string]
        |> CommandInput(flags: map.new())
        |> ping(task.new(at: [], run: fn(_input, _task) { Ok("") }))
      Nil
    }
  }

  assert Ok(task) =
    workbook()
    |> map.get(["test"])
  [#("target", target_flag)]
  |> map.from_list
  |> CommandInput(args: input.args)
  |> task.trainer(gleam(["test"]))(task)
}

fn hello_lucy(input: CommandInput, _task: Task(Result)) -> Result {
  let lucy =
    "
                         &                 
                        &&                 
       &&&              &*                 
          #&&%         &&                  
              &&&     &&*                  
                ,&&,  ,                    
                         &&&&&&&&&&&# ,    
                  &&  #                    
                   &&&&                    
                ,&&&&&,                    
              &&&    &&                    
          ,&&         &&                   
                       &                   
"
    |> shellout.style(
      with: style_flags(input.flags)
      |> map.merge(from: shellout.display(["bold", "italic"])),
      custom: util.lookups,
    )
  let sparkles = shellout.style(
    _,
    with: shellout.display(["bold", "italic"])
    |> map.merge(from: shellout.color(["buttercup"])),
    custom: util.lookups,
  )
  let hello_joe =
    [
      "         ",
      "✨"
      |> sparkles,
      "Hello, world!"
      |> shellout.style(
        with: shellout.display(["bold", "italic"])
        |> map.merge(from: shellout.color(["purple"])),
        custom: util.lookups,
      ),
      "✨"
      |> sparkles,
    ]
    |> string.join(with: " ")
  let welcome =
    [
      "Welcome to ",
      "Gleam"
      |> shellout.style(
        with: shellout.display(["bold"])
        |> map.merge(shellout.color(["pink"])),
        custom: util.lookups,
      ),
      "! It's great to have you.",
    ]
    |> string.concat
  let uri = shellout.style(
    _,
    with: shellout.display(["italic"])
    |> map.merge(from: shellout.color(["boi-blue"])),
    custom: util.lookups,
  )
  let website =
    [
      "https://"
      |> uri,
      "gleam.run"
      |> shellout.style(
        with: shellout.display(["italic"])
        |> map.merge(shellout.color(["pink"])),
        custom: util.lookups,
      ),
      "/documentation/"
      |> uri,
    ]
    |> string.concat
  [
    lucy,
    hello_joe,
    "",
    welcome,
    "",
    "For more information check out the website:",
    website,
  ]
  |> string.join(with: "\n")
  |> Ok
}

fn dependency_name(path: List(String), from config: Toml) {
  let [name] = path
  let is_dep = fn(which_deps) {
    [which_deps, name]
    |> toml.decode(from: config, expect: dynamic.string)
  }
  try _version =
    "dependencies"
    |> is_dep
    |> result.lazy_or(fn() { is_dep("dev-dependencies") })
    |> result.map_error(with: fn(_snag) {
      ["dependency `", name, "` not found"]
      |> string.concat
      |> snag.new
    })
  Ok(name)
}

fn self_or_dependency(
  input: CommandInput,
  task: Task(Result),
  self self_fun: fn(String, Toml) -> Result,
  or dep_fun: fn(Toml) -> Result,
) -> gleam.Result(#(String, Bool), Snag) {
  assert Parsed(config) = task.config

  try self =
    ["name"]
    |> toml.decode(from: config, expect: dynamic.string)
  let is_self = input.args == [] || input.args == [self]

  case is_self {
    True -> self_fun(self, config)
    False -> dep_fun(config)
  }
  |> result.map(with: fn(item) { #(item, is_self) })
}

// TODO: remove for gleam_stdlib > 0.22.1
fn dynamic_list(
  of decoder_type: fn(dynamic.Dynamic) -> gleam.Result(a, dynamic.DecodeErrors),
) -> dynamic.Decoder(List(a)) {
  do_dynamic_list(decoder_type)
}

if erlang {
  fn do_dynamic_list(decoder_type) {
    dynamic.list(of: decoder_type)
  }
}

if javascript {
  fn do_dynamic_list(decoder_type) {
    fn(dynamic) {
      try list = decode_list(dynamic)
      list
      |> list.try_map(decoder_type)
      |> result.map_error(with: list.map(_, with: push_path(_, "*")))
    }
  }

  fn push_path(error, name) {
    let name = dynamic.from(name)
    let decoder =
      dynamic.any([
        dynamic.string,
        fn(x) { result.map(dynamic.int(x), int.to_string) },
      ])
    let name = case decoder(name) {
      Ok(name) -> name
      Error(_) ->
        ["<", dynamic.classify(name), ">"]
        |> string.concat
    }
    dynamic.DecodeError(..error, path: [name, ..error.path])
  }

  external fn decode_list(
    dynamic.Dynamic,
  ) -> gleam.Result(List(dynamic.Dynamic), dynamic.DecodeErrors) =
    "../../rad_ffi.mjs" "tmp_decode_list"
}
