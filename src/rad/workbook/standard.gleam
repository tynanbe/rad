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
import gleam/dict
import gleam/dynamic
import gleam/function
import gleam/http.{type Header}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/uri.{Uri}
import glint.{type CommandInput, CommandInput}
import glint/flag.{Flag}
import rad
import rad/task.{type Result, type Task, Parsed}
import rad/toml.{type Toml}
import rad/util
import rad/workbook.{type Workbook}
import shellout.{type StyleFlags, LetBeStderr, LetBeStdout}
import snag.{type Snag}
@target(erlang)
import gleam/http/request
@target(erlang)
import gleam/httpc
@target(javascript)
import gleam/json

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
    #(
      "display",
      flag.string_list()
        |> flag.default(of: ["bold"])
        |> flag.description(of: "Set display styles")
        |> flag.build,
    ),
    #(
      "color",
      flag.string_list()
        |> flag.default(of: ["pink"])
        |> flag.description(of: "Set a foreground color")
        |> flag.build,
    ),
    #(
      "background",
      flag.string_list()
        |> flag.default(of: [])
        |> flag.description(of: "Set a background color")
        |> flag.build,
    ),
  ]

  let toml =
    "gleam.toml"
    |> toml.parse_file
    |> result.lazy_unwrap(or: toml.new)

  let target_flags = [
    #(
      "target",
      flag.string_list()
        |> flag.default(
          of: ["rad", "targets"]
          |> toml.decode(from: toml, expect: dynamic.list(of: dynamic.string))
          |> result.lazy_or(fn() {
            ["target"]
            |> toml.decode(from: toml, expect: dynamic.string)
            |> result.map(with: fn(target) { [target] })
          })
          |> result.unwrap(or: ["erlang"]),
        )
        |> flag.description(of: "The platforms to target")
        |> flag.build,
    ),
  ]

  let package_flags = [
    #(
      "all",
      flag.bool()
        |> flag.default(of: False)
        |> flag.description(of: "Run the task for all packages")
        |> flag.build,
    ),
  ]

  let watch_flags = [
    #(
      "no-docs",
      flag.bool()
        |> flag.default(of: False)
        |> flag.description(of: "Disable docs handling")
        |> flag.build,
    ),
    #(
      "port",
      flag.int()
        |> flag.default(of: 7000)
        |> flag.description(of: "Request live reloads over port (default 7000)")
        |> flag.build,
    ),
    ..target_flags
  ]

  workbook.new()
  |> workbook.task(
    add: []
    |> task.new(run: root)
    |> task.flag(
      called: "version",
      explained: "Print rad's version",
      expect: flag.bool,
      default: False,
    )
    |> task.with_config
    |> task.with_manifest,
  )
  |> workbook.task(
    add: ["add"]
    |> task.new(run: task.gleam(["add"]))
    |> task.shortdoc("Add new project dependencies")
    |> task.flag(
      called: "dev",
      explained: "Add the packages as dev-only dependencies",
      expect: flag.bool,
      default: False,
    )
    |> task.parameter(with: "..<packages>", of: "Names of Hex packages"),
  )
  |> workbook.task(
    add: ["build"]
    |> task.new(run: task.gleam(["build"]))
    |> task.for(each: task.targets)
    |> task.shortdoc("Build the project")
    |> task.flag(
      called: "warnings-as-errors",
      explained: "Emit compile time warnings as errors",
      expect: flag.bool,
      default: False,
    )
    |> task.flags(add: target_flags),
  )
  |> workbook.task(
    add: ["check"]
    |> task.new(run: task.gleam(["check"]))
    |> task.shortdoc("Type check the project"),
  )
  |> workbook.task(
    add: ["clean"]
    |> task.new(run: task.gleam(["clean"]))
    |> task.shortdoc("Clean build artifacts"),
  )
  |> workbook.task(
    add: ["config"]
    |> task.new(run: config)
    |> task.shortdoc("Print project config values")
    |> task.parameter(with: "<path>", of: "TOML breadcrumbs, space-separated")
    |> task.with_config,
  )
  |> workbook.task(
    add: ["deps"]
    |> task.new(run: workbook.help(from: workbook))
    |> task.shortdoc("Work with dependency packages")
    |> task.with_config,
  )
  |> workbook.task(
    add: ["deps", "list"]
    |> task.new(run: task.gleam(["deps", "list"]))
    |> task.shortdoc("List dependency packages"),
  )
  |> workbook.task(
    add: ["deps", "update"]
    |> task.new(run: task.gleam(["deps", "update"]))
    |> task.shortdoc("Update dependency packages"),
  )
  |> workbook.task(
    add: ["docs"]
    |> task.new(run: workbook.help(from: workbook))
    |> task.shortdoc("Work with HTML documentation")
    |> task.with_config,
  )
  |> workbook.task(
    add: ["docs", "build"]
    |> task.new(run: docs_build)
    |> task.for(
      each: task.packages
      |> task.or(cond: "all", otherwise: task.arguments),
    )
    |> task.shortdoc("Render HTML documentation")
    |> task.flags(add: package_flags)
    |> task.parameter(
      with: "..[packages]",
      of: "Package names (default: current project)",
    )
    |> task.with_config,
  )
  |> workbook.task(
    add: ["docs", "serve"]
    |> task.new(run: docs_serve)
    |> task.shortdoc("Serve HTML documentation")
    |> task.flag(
      called: "host",
      explained: "Bind to host (default localhost)",
      expect: flag.string,
      default: "localhost",
    )
    |> task.flag(
      called: "no-live",
      explained: "Disable live reloading",
      expect: flag.bool,
      default: False,
    )
    |> task.flag(
      called: "port",
      explained: "Listen on port (default 7000)",
      expect: flag.int,
      default: 7000,
    )
    |> task.flags(add: package_flags)
    |> task.parameter(
      with: "..[packages]",
      of: "Package names to build docs for (default: current project)",
    )
    |> task.with_config,
  )
  |> workbook.task(
    add: ["format"]
    |> task.new(run: format)
    |> task.for(each: task.formatters)
    |> task.delimit(with: "\n\n")
    |> task.shortdoc("Format source code")
    |> task.flag(
      called: "check",
      explained: "Check if inputs are formatted without changing them",
      expect: flag.bool,
      default: False,
    )
    |> task.flag(
      called: "fail",
      explained: "",
      expect: flag.bool,
      default: False,
    ),
  )
  // TODO: |> task.parameter(with: "..[files]", of: "Files to format (default: .)"),
  |> workbook.task(
    add: ["Hello,", "Lucy!"]
    |> task.new(run: hello_lucy)
    |> task.flags(add: list.drop(from: style_flags, up_to: 1))
    |> task.shortdoc("Greet Gleam's mascot ✨"),
  )
  |> workbook.task(
    add: ["help"]
    |> task.new(run: workbook.help(from: workbook))
    |> task.shortdoc("Print help information")
    |> task.parameter(
      with: "[subcommand]",
      of: "Subcommand breadcrumbs, space-separated",
    )
    |> task.with_config,
  )
  |> workbook.task(
    add: ["name"]
    |> task.new(run: name)
    |> task.for(
      each: task.packages
      |> task.or(cond: "all", otherwise: task.arguments),
    )
    |> task.shortdoc("Print package names")
    |> task.flags(add: package_flags)
    |> task.flags(add: style_flags)
    |> task.parameter(
      with: "..[packages]",
      of: "Package names (default: current project)",
    )
    |> task.with_config,
  )
  |> workbook.task(
    add: ["origin"]
    |> task.new(run: origin)
    |> task.shortdoc("Print the repository URL"),
  )
  |> workbook.task(
    add: ["ping"]
    |> task.new(run: ping)
    |> task.for(each: task.arguments)
    |> task.shortdoc("Fetch HTTP status codes")
    |> task.parameter(with: "..<uris>", of: "Request locations"),
  )
  |> workbook.task(
    add: ["shell"]
    |> task.new(run: shell)
    |> task.shortdoc("Start a shell")
    |> task.parameter(
      with: "[runtime]",
      of: "Runtime name or alias (default: erl; options: deno, erl, iex, node)",
    )
    |> task.with_config,
  )
  |> workbook.task(
    add: ["test"]
    |> task.new(run: tests)
    |> task.for(each: task.targets)
    |> task.shortdoc("Run the project tests")
    |> task.flags(add: target_flags)
    |> task.with_config,
  )
  |> workbook.task(
    add: ["tree"]
    |> task.new(run: tree)
    |> task.shortdoc("Print the file structure"),
  )
  |> workbook.task(
    add: ["version"]
    |> task.new(run: version)
    |> task.for(
      each: task.packages
      |> task.or(cond: "all", otherwise: task.arguments),
    )
    |> task.shortdoc("Print package versions")
    |> task.flags(add: package_flags)
    |> task.flag(
      called: "bare",
      explained: "Omit package names",
      expect: flag.bool,
      default: False,
    )
    |> task.flags(add: style_flags)
    |> task.parameter(
      with: "..[packages]",
      of: "Package names (default: current project)",
    )
    |> task.with_config
    |> task.with_manifest,
  )
  |> workbook.task(
    add: ["watch"]
    |> task.new(run: watch)
    |> task.shortdoc("Automate project tasks")
    |> task.flags(add: watch_flags),
  )
  |> workbook.task(
    add: ["watch", "do"]
    |> task.new(run: watch_do)
    |> task.flags(add: watch_flags),
  )
}

/// Prints [`help`](../workbook.html#help) information, or `rad`'s version when
/// given the `--version` flag.
///
pub fn root(input: CommandInput, task: Task(Result)) -> Result {
  let ver =
    "version"
    |> flag.get_bool(from: input.flags)
    |> result.unwrap(or: False)
  case ver {
    True -> {
      let flags =
        [
          #(
            "bare",
            flag.bool()
              |> flag.default(of: False)
              |> flag.build,
          ),
        ]
        |> flag.build_map
      let version = fn(args) {
        args
        |> CommandInput(flags: flags, named_args: dict.new())
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
  let assert Parsed(config) = task.config
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
  let all =
    "all"
    |> flag.get_bool(from: input.flags)
    |> result.unwrap(or: False)

  use #(name, is_self) <- result.try(
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
    ),
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
      |> shellout.command(run: "gleam", in: path, opt: [
        LetBeStderr,
        LetBeStdout,
      ])
      |> result.replace_error(snag.new("failed building docs"))
      |> result.try(apply: fn(_output) {
        case is_self {
          True -> Ok("")
          False -> {
            let docs_dir = "./build/dev/docs/"
            use _result <- result.try(case util.is_directory(docs_dir) {
              True -> Ok("")
              False -> util.make_directory(docs_dir)
            })
            let new_path =
              [docs_dir, name]
              |> string.concat
            use _result <- result.try(
              new_path
              |> util.recursive_delete,
            )
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
/// The `build/dev/docs/` directory is by default served at
/// [http://localhost:7000/](http://localhost:7000/) with support for live
/// reloading. Host, port, and live reloading support can all be altered via
/// input flags. For example, setting `--host=0.0.0.0` allows the server to
/// respond to external requests.
///
pub fn docs_serve(input: CommandInput, _task: Task(Result)) -> Result {
  let assert Ok(docs_build_task) =
    ["docs", "build"]
    |> workbook.get(from: workbook())
  use _output <- result.try(
    input
    |> docs_build_task.run(docs_build_task),
  )

  io.println("")

  let assert Ok(host) =
    "host"
    |> flag.get_string(from: input.flags)
  let assert Ok(flags) = case host {
    "localhost" ->
      "--host=127.0.0.1"
      |> flag.update_flags(in: input.flags)
    _else -> Ok(input.flags)
  }

  let args =
    [
      [util.rad_path <> "/priv/node_modules/wonton/cli.js"],
      util.relay_flags(flags),
      ["--", "./build/dev/docs"],
    ]
    |> list.concat
  util.javascript_run(
    deno: [
      "run",
      "--allow-net",
      "--allow-read",
      "--allow-sys",
      "--unstable",
      "--",
      ..args
    ],
    or: args,
    opt: [LetBeStderr, LetBeStdout],
  )
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
  let fail =
    "fail"
    |> flag.get_bool(from: input.flags)
    |> result.unwrap(or: False)
  use _result <- result.try(case fail {
    True -> snag.error("invalid formatter in `gleam.toml`")
    False -> Ok("")
  })

  use result <- result.try(
    dict.new()
    |> CommandInput(args: [], named_args: dict.new())
    |> task.basic(input.args)(task)
    |> result.map_error(with: fn(_snag) {
      let check =
        "check"
        |> flag.get_bool(from: input.flags)
        |> result.unwrap(or: False)
      case check {
        True -> "failed format check"
        False -> "failed formatting"
      }
      |> snag.new
    }),
  )

  let assert [command, ..] = input.args
  let check =
    "check"
    |> flag.get_bool(from: input.flags)
    |> result.unwrap(or: False)
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
  use #(name, _is_self) <- result.try(
    self_or_dependency(
      input,
      task,
      self: fn(self, _config) { Ok(self) },
      or: dependency_name(input.args, from: _),
    ),
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
  |> dict.filter(keeping: fn(_key, x) {
    let Flag(value: value, ..) = x
    case value {
      flag.LS(_strings) -> True
      _else -> False
    }
  })
  |> dict.map_values(with: fn(_key, x) {
    x
    |> flag.get_strings_value
    |> result.unwrap(or: [])
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
  use uri_string <- result.try(case input.args {
    [uri_string, ..] -> Ok(uri_string)
    _else -> snag.error("URI not provided")
  })
  use uri <- result.try(
    uri_string
    |> uri.parse
    |> result.map_error(with: fn(_nil) {
      ["invalid URI `", uri_string, "`"]
      |> string.concat
      |> snag.new
    }),
  )
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

@target(erlang)
fn do_ping(uri_string: String, headers: List(Header)) -> gleam.Result(Int, Int) {
  use uri <- result.try(
    uri_string
    |> uri.parse
    |> result.replace_error(400),
  )

  use request <- result.try(
    uri
    |> request.from_uri
    |> result.replace_error(400),
  )

  headers
  |> list.fold(from: request, with: fn(acc, header) {
    request.prepend_header(acc, header.0, header.1)
  })
  |> httpc.send
  |> result.map(with: fn(response) { response.status })
  |> result.replace_error(503)
}

@target(javascript)
fn do_ping(uri_string: String, headers: List(Header)) -> gleam.Result(Int, Int) {
  let headers =
    headers
    |> list.map(with: fn(header) { #(header.0, json.string(header.1)) })
    |> json.object
    |> json.to_string

  let script =
    [
      "fetch('" <> uri_string <> "', " <> headers <> ")",
      ".then(response => response.status)",
      ".catch(() => 503)",
      ".then(console.log)",
    ]
    |> string.concat
  use status <- result.try(
    util.javascript_run(
      deno: ["eval", script, "--unstable"],
      or: ["--eval=" <> script],
      opt: [],
    )
    |> result.replace_error(503),
  )

  let assert Ok(status) =
    status
    |> string.trim
    |> int.parse
  case status < 400 {
    True -> Ok(status)
    False -> Error(status)
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

@target(erlang)
fn do_shell(_input: CommandInput, _task: Task(Result)) -> Result {
  util.refuse_erlang()
}

@target(javascript)
fn do_shell(input: CommandInput, task: Task(Result)) -> Result {
  let options = [LetBeStderr, LetBeStdout]
  let runtime = case input.args {
    [runtime, ..] -> runtime
    _else -> "erlang"
  }
  let javascript =
    [
      "import('" <> util.rad_path <> "/rad_ffi.mjs')",
      ".then(module => module.load_modules())",
    ]
    |> string.concat

  case runtime {
    "elixir" | "iex" -> {
      let assert Parsed(config) = task.config
      use name <- result.try(
        ["name"]
        |> toml.decode(from: config, expect: dynamic.string),
      )
      use ebins <- result.try(
        util.ebin_paths()
        |> result.replace_error(snag.new("failed to find `ebin` paths")),
      )
      [["--eval", "Application.ensure_all_started(:" <> name <> ")
          :code.all_available()
          |> Enum.map(fn {module, _, _} -> List.to_atom(module) end)
          |> :code.ensure_modules_loaded"], [
          "--erl",
          ["-pa", ..ebins]
            |> string.join(with: " "),
        ]]
      |> list.concat
      |> shellout.command(run: "iex", in: ".", opt: options)
      |> result.replace_error(snag.new("failed to run `elixir` shell"))
    }

    "erlang" | "erl" ->
      []
      |> util.erlang_run(opt: options)
      |> result.replace_error(snag.new("failed to run `erlang` shell"))

    "deno" ->
      ["repl", "--eval=" <> javascript, "--allow-all", "--unstable"]
      |> shellout.command(run: "deno", in: ".", opt: options)
      |> result.replace_error(snag.new("failed to run `deno` shell"))

    "nodejs" | "node" ->
      [
        "--interactive",
        "--eval=" <> javascript,
        "--experimental-fetch",
        "--experimental-repl-await",
        "--no-warnings",
      ]
      |> shellout.command(run: "node", in: ".", opt: options)
      |> result.replace_error(snag.new("failed to run `nodejs` shell"))

    _else -> snag.error("unsupported runtime `" <> runtime <> "`")
  }
}

/// Runs your project's unit tests for all specified target/runtimes.
///
/// Accepts the `--target` input flag.
///
/// Note that default target/runtimes can also be specified in your project's
/// `gleam.toml` configuration file.
///
/// ## Examples
///
/// ```toml
/// [rad]
/// targets = ["erlang", "javascript"]
/// ```
///
pub fn tests(input: CommandInput, task: Task(Result)) -> Result {
  let options = [LetBeStderr, LetBeStdout]
  let assert Ok([target]) =
    "target"
    |> flag.get_strings(from: input.flags)

  let build = fn(target) {
    shellout.command(
      run: "gleam",
      with: ["build", "--target=" <> target],
      in: ".",
      opt: options,
    )
    |> result.replace_error(snag.new("failed compiling `" <> target <> "`"))
  }

  let assert Parsed(config) = task.config
  use name <- result.try(
    ["name"]
    |> toml.decode(from: config, expect: dynamic.string),
  )

  case target {
    "erlang" -> {
      use _result <- result.try(build(target))
      ["-noshell", "-eval", name <> "@@main:run(" <> name <> "_test)"]
      |> util.erlang_run(opt: options)
      |> result.replace_error(snag.new("`erlang` tests failed"))
    }

    "javascript" -> {
      use _result <- result.try(build(target))
      let script =
        "import('./build/dev/javascript/"
        <> name
        <> "/"
        <> name
        <> "_test.mjs').then(module => module.main())"
      util.javascript_run(
        deno: ["eval", script, "--unstable"],
        or: ["--eval=" <> script],
        opt: options,
      )
      |> result.replace_error(snag.new("`javascript` tests failed"))
    }

    _else -> snag.error("unsupported target `" <> target <> "`")
  }
}

/// Prints your project's file structure using a tree representation.
///
/// Some paths, such as `.git` and `build` (see [`ignore_glob`](#ignore_glob)),
/// are ignored.
///
/// Requires the `exa` or `tree` command to be available on the system (in order
/// of preference).
///
/// When running `exa`, a `git` status summary is shown for each file.
///
pub fn tree(_input: CommandInput, _task: Task(Result)) -> Result {
  let assert Ok(working_directory) = util.working_directory()
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
      |> list.concat
      |> shellout.command(run: "tree", in: ".", opt: [])
      |> result.replace_error(snag.layer(error, "command `tree` not found"))
  }
  |> result.map_error(
    with: function.compose(
      snag.layer(_, "failed to find a known tree command"),
      snag.layer(_, "failed to run task"),
    ),
  )
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
  let bare =
    "bare"
    |> flag.get_bool(from: input.flags)
    |> result.unwrap(or: False)

  use name <- result.try(case bare {
    True -> Ok(None)
    False ->
      input
      |> name(task)
      |> result.map(with: Some)
  })

  use #(version, _is_self) <- result.try(
    self_or_dependency(
      input,
      task,
      self: fn(_self, config) {
        ["version"]
        |> toml.decode(from: config, expect: dynamic.string)
      },
      or: fn(_config) {
        let assert Parsed(manifest) = task.manifest
        ["packages"]
        |> toml.decode(
          from: manifest,
          expect: dynamic.list(of: toml.from_dynamic),
        )
        |> result.unwrap(or: [])
        |> list.find_map(with: fn(toml) {
          let decode = toml.decode(_, from: toml, expect: dynamic.string)
          use name <- result.try(decode(["name"]))
          case [name] == input.args {
            True -> decode(["version"])
            False -> snag.error("")
          }
        })
        |> result.map_error(with: fn(_nil) {
          let assert [name] = input.args
          ["dependency `", name, "` not found"]
          |> string.concat
          |> snag.new
        })
      },
    ),
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
pub fn watch(input: CommandInput, _task: Task(Result)) -> Result {
  do_watch(input)
}

@target(erlang)
fn do_watch(_input: CommandInput) -> Result {
  util.refuse_erlang()
}

@target(javascript)
fn do_watch(input: CommandInput) -> Result {
  let options = [LetBeStderr, LetBeStdout]
  let assert [command, ..args] as watch_do = case input.args {
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
    |> list.concat
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
          |> list.concat
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
  |> result.map_error(
    with: function.compose(
      snag.layer(_, "failed to find a known watcher command"),
      snag.layer(_, "failed to run task"),
    ),
  )
}

@target(javascript)
@external(javascript, "../../rad_ffi.mjs", "watch_loop")
fn watch_loop(
  on watch_fun: fn() -> gleam.Result(String, #(Int, String)),
  do do_fun: fn() -> gleam.Result(String, #(Int, String)),
) -> gleam.Result(String, Nil)

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
  let no_docs =
    "no-docs"
    |> flag.get_bool(from: input.flags)
    |> result.unwrap(or: False)
  let assert Ok(port) =
    "port"
    |> flag.get_int(from: input.flags)
  let assert Ok(target_flag) =
    "target"
    |> dict.get(input.flags, _)

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
        |> CommandInput(flags: dict.new(), named_args: dict.new())
        |> ping(task.new(at: [], run: fn(_input, _task) { Ok("") }))
      Nil
    }
  }

  let assert Ok(task) =
    workbook()
    |> workbook.get(["test"])
  [#("target", target_flag)]
  |> dict.from_list
  |> CommandInput(args: input.args, named_args: dict.new())
  |> task.trainer(tests)(task)
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
        |> dict.merge(from: shellout.display(["bold", "italic"])),
      custom: util.lookups,
    )
  let sparkles = shellout.style(
    _,
    with: shellout.display(["bold", "italic"])
      |> dict.merge(from: shellout.color(["buttercup"])),
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
            |> dict.merge(from: shellout.color(["purple"])),
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
            |> dict.merge(shellout.color(["pink"])),
          custom: util.lookups,
        ),
      "! It's great to have you.",
    ]
    |> string.concat
  let uri = shellout.style(
    _,
    with: shellout.display(["italic"])
      |> dict.merge(from: shellout.color(["boi-blue"])),
    custom: util.lookups,
  )
  let website =
    [
      "https://"
        |> uri,
      "gleam.run"
        |> shellout.style(
          with: shellout.display(["italic"])
            |> dict.merge(shellout.color(["pink"])),
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
  let assert [name] = path
  let is_dep = fn(which_deps) {
    [which_deps, name]
    |> toml.decode(from: config, expect: dynamic.string)
  }
  use _version <- result.try(
    "dependencies"
    |> is_dep
    |> result.lazy_or(fn() { is_dep("dev-dependencies") })
    |> result.map_error(with: fn(_snag) {
      ["dependency `", name, "` not found"]
      |> string.concat
      |> snag.new
    }),
  )
  Ok(name)
}

fn self_or_dependency(
  input: CommandInput,
  task: Task(Result),
  self self_fun: fn(String, Toml) -> Result,
  or dep_fun: fn(Toml) -> Result,
) -> gleam.Result(#(String, Bool), Snag) {
  let assert Parsed(config) = task.config

  use self <- result.try(
    ["name"]
    |> toml.decode(from: config, expect: dynamic.string),
  )
  let is_self = input.args == [] || input.args == [self]

  case is_self {
    True -> self_fun(self, config)
    False -> dep_fun(config)
  }
  |> result.map(with: fn(item) { #(item, is_self) })
}
