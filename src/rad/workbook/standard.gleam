//// TODO: colour
//// TODO
////

import gleam
import gleam/dynamic
import gleam/function
import gleam/int
import gleam/io
import gleam/list
import gleam/map
import gleam/option.{None, Some}
import gleam/pair
import gleam/result
import gleam/string
import glint.{CommandInput}
import glint/flag
import rad
import rad/task.{
  Parsed, Result, Task, arguments, flag, flags, for, gleam, new, parameter, shortdoc,
  targets, with_config,
}
import rad/toml
import rad/util
import rad/workbook.{Workbook, help, task}
import shellout.{LetBeStderr, LetBeStdout, StyleFlags}
import snag.{Snag}

/// TODO
///
pub const ignore_glob = ".git|_build|build|deps|node_modules"

/// TODO
///
pub fn main() -> Nil {
  workbook()
  |> rad.do_main
}

/// TODO
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
    |> toml.decode(from: toml, expect: dynamic.list(of: dynamic.string))
    |> result.lazy_or(fn() {
      ["target"]
      |> toml.decode(from: toml, expect: dynamic.string)
      |> result.map(with: fn(target) { [target] })
    })
    |> result.unwrap(or: ["erlang"])
    |> flag.strings(called: "target", explained: "The platform(s) to target"),
  ]

  let docs_flags = [
    flag.bool(
      called: "all",
      default: False,
      explained: "Build docs for all packages",
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
    |> shortdoc("Add a new project dependency")
    |> flag(
      called: "dev",
      explained: "Add the package(s) as dev-only dependencies",
      expect: flag.bool,
      default: False,
    )
    |> parameter(with: "..<packages>", of: "Name(s) of Hex package(s)"),
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
    |> flags(target_flags),
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
    |> parameter(with: "<path>", of: "TOML breadcrumb(s), space-separated")
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
    add: ["docs"]
    |> new(run: help(from: workbook))
    |> shortdoc("Work with HTML documentation")
    |> with_config,
  )
  |> task(
    add: ["docs", "build"]
    |> new(run: docs_build)
    |> shortdoc("Render HTML documentation")
    |> flags(docs_flags)
    |> parameter(
      with: "..[packages]",
      of: "Package name(s) (default: current project)",
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
    |> flags(docs_flags)
    |> parameter(
      with: "..[packages]",
      of: "Package name(s) to build docs for (default: current project)",
    ),
  )
  |> task(
    add: ["format"]
    |> new(run: format)
    |> shortdoc("Format source code")
    |> flag(
      called: "check",
      explained: "Check if inputs are formatted without changing them",
      expect: flag.bool,
      default: False,
    )
    |> parameter(with: "..[files]", of: "Files to format (default: .)"),
  )
  |> task(
    add: ["Hello,", "Lucy!"]
    |> new(run: hello_lucy)
    |> flags(list.drop(from: style_flags, up_to: 1))
    |> shortdoc("Greet Gleam's mascot ✨"),
  )
  |> task(
    add: ["help"]
    |> new(run: help(from: workbook))
    |> shortdoc("Print help information")
    |> parameter(
      with: "[subcommand]",
      of: "Subcommand breadcrumb(s), space-separated",
    )
    |> with_config,
  )
  |> task(
    add: ["name"]
    |> new(run: name)
    |> for(each: arguments)
    |> shortdoc("Print a package name")
    |> flags(style_flags)
    |> parameter(
      with: "[package]",
      of: "Package name (default: current project)",
    )
    |> with_config,
  )
  |> task(
    add: ["origin"]
    |> new(run: origin)
    |> shortdoc("Print the repository URL"),
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
    |> flags(target_flags),
  )
  |> task(
    add: ["tree"]
    |> new(run: tree)
    |> shortdoc("Print the file structure"),
  )
  |> task(
    add: ["version"]
    |> new(run: version)
    |> for(each: arguments)
    |> shortdoc("Print a package version")
    |> flag(
      called: "bare",
      explained: "Omit the package name",
      expect: flag.bool,
      default: False,
    )
    |> flags(style_flags)
    |> parameter(
      with: "[package]",
      of: "Package name (default: current project)",
    )
    |> with_config,
  )
  |> task(
    add: ["watch"]
    |> new(run: watch)
    |> shortdoc("Automate some project tasks")
    |> flags(watch_flags),
  )
  |> task(
    add: ["watch", "do"]
    |> new(run: watch_do)
    |> flags(watch_flags),
  )
}

/// TODO
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

/// TODO
///
pub fn config(input: CommandInput, task: Task(Result)) -> Result {
  assert Parsed(toml) = task.config
  input.args
  |> toml.decode(from: toml, expect: dynamic.dynamic)
  |> result.map(with: toml.encode_json)
}

/// TODO: split out `all`, `do_docs_build`
/// TODO
///
pub fn docs_build(input: CommandInput, task: Task(Result)) -> Result {
  assert Ok(flag.B(all)) =
    "all"
    |> flag.get_value(from: input.flags)
  let input = case all {
    True -> {
      // Prepare to build documentation for all Gleam dependencies
      assert Ok(flags) =
        "--all=false"
        |> flag.update_flags(in: input.flags)
      assert Parsed(toml) = task.config
      let dependencies =
        ["dependencies"]
        |> toml.decode_every(from: toml, expect: dynamic.string)
        |> result.unwrap(or: [])
      let dev_dependencies =
        ["dev-dependencies"]
        |> toml.decode_every(from: toml, expect: dynamic.string)
        |> result.unwrap(or: [])
      [dependencies, dev_dependencies]
      |> list.flatten
      |> list.map(with: pair.first)
      |> list.unique
      |> list.filter(for: fn(name) {
        // Gleam packages only
        ["./build/packages/", name, "/gleam.toml"]
        |> string.concat
        |> util.is_file
      })
      |> function.tap(fn(dependencies) {
        case dependencies {
          [] -> Nil
          _else -> {
            // Build documentation for the base project too
            let _result =
              []
              |> CommandInput(flags: flags)
              |> docs_build(task)
            io.println("")
          }
        }
      })
      |> CommandInput(flags: flags)
    }
    False -> input
  }
  let args = input.args
  let extra_args = case args {
    [_, ..args] if args != [] -> Some(args)
    _else -> None
  }
  try #(name, path) = case extra_args {
    None if args == [] ->
      #("", ".")
      |> Ok
    _else ->
      args
      |> list.take(up_to: 1)
      |> util.dependency
      |> result.map(with: fn(name) {
        #(name, string.concat(["./build/packages/", name]))
      })
  }
  let result =
    shellout.command(
      run: "gleam",
      with: ["docs", "build"],
      in: path,
      opt: [LetBeStderr, LetBeStdout],
    )
    |> result.replace_error(snag.new("task failed"))
    |> result.then(apply: fn(_output) {
      case path {
        "." -> Ok("")
        _else -> {
          let new_path =
            ["./build/dev/docs/", name]
            |> string.concat
          try _result = util.recursive_delete(new_path)
          [path, "/build/dev/docs/", name]
          |> string.concat
          |> util.rename(to: new_path)
        }
      }
    })
  case extra_args {
    Some(args) -> {
      io.println("")
      CommandInput(..input, args: args)
      |> docs_build(task)
    }
    None -> result
  }
}

/// TODO
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

/// TODO
///
pub type Formatter {
  Formatter(name: String, check: List(String), run: List(String))
}

/// TODO
///
pub fn format(input: CommandInput, task: Task(Result)) -> Result {
  let formatters = [
    Formatter(
      name: "gleam",
      check: ["gleam", "format", "--check"],
      run: ["gleam", "format"],
    ),
    ..formatters_from_config()
    |> list.map(with: result.map_error(_, with: fn(snag) {
      Snag(..snag, issue: "invalid `[[rad.formatters]]` in `gleam.toml`")
      |> snag.pretty_print
      |> string.trim
      |> string.append(suffix: "\n")
      |> io.println
    }))
    |> result.values
  ]

  assert Ok(flag.B(check)) =
    "check"
    |> flag.get_value(from: input.flags)
  let #(action, extra, failure) = case check {
    True -> #("   Checking", " formatting", "format check")
    False -> #(" Formatting", "", "formatting")
  }

  let errors =
    formatters
    |> list.filter_map(with: fn(formatter) {
      [
        action
        |> shellout.style(with: shellout.color(["magenta"]), custom: []),
        " ",
        formatter.name,
        extra,
        "...",
      ]
      |> string.concat
      |> io.println
      let command = case check {
        True -> formatter.check
        False -> formatter.run
      }
      let result =
        CommandInput(..input, flags: map.new())
        |> task.basic(command)(task)
        |> result.map_error(with: fn(_snag) {
          string.concat(["`", formatter.name, "` formatter failed"])
        })
      case result {
        Ok(_output) -> Error(Nil)
        Error(message) -> Ok(message)
      }
    })
  case errors {
    [] -> Ok("")
    _else -> {
      io.println("")
      [failure, " failed"]
      |> string.concat
      |> Snag(cause: errors)
      |> Error
    }
  }
}

/// TODO
///
fn formatters_from_config() -> List(gleam.Result(Formatter, Snag)) {
  let dynamic_strings = fn(name) {
    dynamic.field(named: name, of: dynamic.list(of: dynamic.string))
  }
  let requirements =
    Formatter
    |> dynamic.decode3(
      dynamic.field(named: "name", of: dynamic.string),
      dynamic_strings("check"),
      dynamic_strings("run"),
    )
  let toml =
    "gleam.toml"
    |> toml.parse_file
    |> result.lazy_unwrap(or: toml.new)

  ["rad", "formatters"]
  |> toml.decode(from: toml, expect: dynamic.list(of: toml.from_dynamic))
  |> result.unwrap(or: [])
  |> list.map(with: toml.decode(from: _, get: [], expect: requirements))
}

/// TODO
///
pub fn name(input: CommandInput, task: Task(Result)) -> Result {
  assert Parsed(toml) = task.config
  try self =
    ["name"]
    |> toml.decode(from: toml, expect: dynamic.string)
  case input.args == [] || input.args == [self] {
    True -> Ok(self)
    False -> util.dependency(input.args)
  }
  |> result.map(with: shellout.style(
    _,
    with: style_flags(input.flags),
    custom: util.lookups,
  ))
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

/// TODO
///
pub fn origin(_input: CommandInput, _task: Task(Result)) -> Result {
  shellout.command(
    run: "git",
    with: ["remote", "get-url", "origin"],
    in: ".",
    opt: [],
  )
  |> result.replace_error(snag.new("git remote `origin` not found"))
}

/// TODO
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
        assert Parsed(toml) = task.config
        try name =
          ["name"]
          |> toml.decode(from: toml, expect: dynamic.string)
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
        |> snag.new
        |> Error
    }
  }
}

/// TODO
///
pub fn tree(_input: CommandInput, _task: Task(Result)) -> Result {
  assert Ok(working_directory) = util.working_directory()
  let result =
    [
      "--all",
      "--color=always",
      "--git-ignore",
      ["--ignore-glob=", ignore_glob]
      |> string.concat,
      "--long",
      "--git",
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

/// TODO
///
pub fn version(input: CommandInput, task: Task(Result)) -> Result {
  assert Ok(flag.B(bare)) =
    "bare"
    |> flag.get_value(from: input.flags)
  assert Parsed(toml) = task.config

  try name = case bare {
    True -> Ok(None)
    False ->
      input
      |> name(task)
      |> result.map(with: Some)
  }

  try self =
    ["name"]
    |> toml.decode(from: toml, expect: dynamic.string)
  try version = case input.args == [] || input.args == [self] {
    True ->
      ["version"]
      |> toml.decode(from: toml, expect: dynamic.string)
    False -> util.packages(input.args)
  }
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

/// TODO
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
    let rad = util.which_rad()
    let flags = util.relay_flags(input.flags)
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
        ["--postpone"],
        ["--watch-when-idle"],
        ["--", rad, "watch", "do", ..flags],
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
            ["watch", "do", ..flags]
            |> shellout.command(run: rad, in: ".", opt: options)
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

/// TODO
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
      ["http://localhost:", int.to_string(port), "/wonton-update"]
      |> string.concat
      |> util.ping
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
