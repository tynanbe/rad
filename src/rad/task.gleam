import gleam/dynamic
import gleam/function
import gleam/int
import gleam/io
import gleam/list
import gleam/map
import gleam/option.{None, Option, Some}
import gleam/order.{Order}
import gleam/pair
import gleam/result
import gleam/string
import glint.{CommandInput}
import glint/flag.{Flag}
import rad/toml
import rad/util.{rad_path}
import shellout.{LetBeStderr, LetBeStdout, Lookups, StyleFlags}
import snag.{Snag}

/// TODO
///
pub const ignore_glob = ".git|_build|build|deps|node_modules"

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
pub const flag_color = "purple"

/// TODO
///
pub const heading_color = "buttercup"

/// TODO
///
pub const parameter_color = "mint"

/// TODO
///
pub const path_color = "boi-blue"

/// TODO
///
pub const subcommand_color = "mint"

const tab = "    "

/// TODO
///
pub type Task(any) {
  Task(
    path: List(String),
    run: fn(CommandInput) -> any,
    flags: List(Flag),
    shortdoc: String,
    parameters: List(#(String, String)),
  )
}

/// TODO
///
pub type TaskResult =
  Result(String, Snag)

/// TODO
///
pub type Tasks =
  List(Task(TaskResult))

/// TODO
///
pub fn tasks() -> Tasks {
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

  [
    Task(
      path: [],
      run: root,
      flags: [
        flag.bool(
          called: "version",
          default: False,
          explained: "Print rad's version",
        ),
      ],
      shortdoc: "",
      parameters: [],
    ),
    Task(
      path: ["add"],
      run: gleam(["add"], _),
      flags: [
        flag.bool(
          called: "dev",
          default: False,
          explained: "Add the packages as dev-only dependencies",
        ),
      ],
      shortdoc: "Add a new project dependency",
      parameters: [#("..<packages>", "Name(s) of Hex package(s)")],
    ),
    Task(
      path: ["build"],
      run: multitarget(gleam(["build"], _), _),
      flags: [
        flag.bool(
          called: "warnings-as-errors",
          default: False,
          explained: "Emit compile time warnings as errors",
        ),
        ..target_flags
      ],
      shortdoc: "Build the project",
      parameters: [],
    ),
    Task(
      path: ["check"],
      run: gleam(["check"], _),
      flags: [],
      shortdoc: "Type check the project",
      parameters: [],
    ),
    Task(
      path: ["clean"],
      run: gleam(["clean"], _),
      flags: [],
      shortdoc: "Clean build artifacts",
      parameters: [],
    ),
    Task(
      path: ["config"],
      run: config,
      flags: [],
      shortdoc: "Print project config values",
      parameters: [#("<path>", "TOML breadcrumb(s), space-separated")],
    ),
    Task(
      path: ["deps"],
      run: help(tasks(), ["deps"], _),
      flags: [],
      shortdoc: "Work with dependency packages",
      parameters: [],
    ),
    Task(
      path: ["deps", "list"],
      run: gleam(["deps", "list"], _),
      flags: [],
      shortdoc: "List dependency packages",
      parameters: [],
    ),
    Task(
      path: ["docs"],
      run: help(tasks(), ["docs"], _),
      flags: [],
      shortdoc: "Work with HTML documentation",
      parameters: [],
    ),
    Task(
      path: ["docs", "build"],
      run: docs_build,
      flags: docs_flags,
      shortdoc: "Render HTML documentation",
      parameters: [
        #("..[packages]", "Package name(s) (default: current project)"),
      ],
    ),
    Task(
      path: ["docs", "serve"],
      run: docs_serve,
      flags: [
        flag.string(
          called: "host",
          default: "localhost",
          explained: "Bind to host (default localhost)",
        ),
        flag.bool(
          called: "no-live",
          default: False,
          explained: "Disable live reloading",
        ),
        flag.int(
          called: "port",
          default: 7000,
          explained: "Listen on port (default 7000)",
        ),
        ..docs_flags
      ],
      shortdoc: "Serve HTML documentation",
      parameters: [
        #(
          "..[packages]",
          "Package name(s) to build docs for (default: current project)",
        ),
      ],
    ),
    Task(
      path: ["format"],
      run: format,
      flags: [
        flag.bool(
          called: "check",
          default: False,
          explained: "Check if inputs are formatted without changing them",
        ),
      ],
      shortdoc: "Format source code",
      parameters: [#("..[files]", "Files to format (default: .)")],
    ),
    Task(
      path: ["help"],
      run: help(tasks(), ["help"], _),
      flags: [],
      shortdoc: "Print help information",
      parameters: [
        #("[subcommand]", "Subcommand breadcrumb(s), space-separated"),
      ],
    ),
    Task(
      path: ["name"],
      run: name,
      flags: style_flags,
      shortdoc: "Print a package name",
      parameters: [#("[package]", "Package name (default: current project)")],
    ),
    Task(
      path: ["origin"],
      run: origin,
      flags: [],
      shortdoc: "Print the repository URL",
      parameters: [],
    ),
    Task(
      path: ["shell"],
      run: shell,
      flags: [],
      shortdoc: "Start a shell",
      parameters: [
        #(
          "[runtime]",
          "Runtime name or alias (default: erl; options: erl, iex, node)",
        ),
      ],
    ),
    Task(
      path: ["test"],
      run: multitarget(gleam(["test"], _), _),
      flags: target_flags,
      shortdoc: "Run the project tests",
      parameters: [],
    ),
    Task(
      path: ["tree"],
      run: tree,
      flags: [],
      shortdoc: "Print the file structure",
      parameters: [],
    ),
    Task(
      path: ["version"],
      run: version,
      flags: [
        flag.bool(
          called: "bare",
          default: False,
          explained: "Omit the package name",
        ),
        ..style_flags
      ],
      shortdoc: "Print a package version",
      parameters: [#("[package]", "Package name (default: current project)")],
    ),
    Task(
      path: ["watch"],
      run: watch,
      flags: watch_flags,
      shortdoc: "Automate the project tests",
      parameters: [],
    ),
    Task(
      path: ["watch", "do"],
      run: watch_do,
      flags: watch_flags,
      shortdoc: "",
      parameters: [],
    ),
  ]
}

/// TODO
///
pub fn tasks_from_config() -> List(Result(Task(TaskResult), Snag)) {
  let shortdoc = ""
  let dynamic_strings = fn(name) {
    dynamic.field(named: name, of: dynamic.list(of: dynamic.string))
  }
  let requirements =
    fn(path, run) {
      Task(
        path: path,
        run: user(run, _),
        flags: [],
        shortdoc: shortdoc,
        parameters: [],
      )
    }
    |> dynamic.decode2(dynamic_strings("path"), dynamic_strings("run"))

  "gleam.toml"
  |> toml.parse_file
  |> result.lazy_unwrap(or: toml.new)
  |> toml.decode(
    get: ["rad", "tasks"],
    expect: dynamic.list(of: toml.from_dynamic),
  )
  |> result.unwrap(or: [])
  |> list.map(with: fn(toml) {
    try task =
      []
      |> toml.decode(from: toml, expect: requirements)
    let shortdoc =
      ["shortdoc"]
      |> toml.decode(from: toml, expect: dynamic.string)
      |> result.unwrap(or: shortdoc)
    Task(..task, shortdoc: shortdoc)
    |> Ok
  })
}

/// Sort [`Tasks`](#Tasks) alphabetically by `path`.
///
pub fn sort_tasks(tasks: Tasks) -> Tasks {
  list.sort(
    tasks,
    by: fn(a, b) {
      let #(a, b) = remove_common_path(a.path, b.path)
      string.compare(a, b)
    },
  )
}

fn remove_common_path(a: List(String), b: List(String)) -> #(String, String) {
  let nonempty = fn(strings) {
    case strings {
      [] -> [""]
      _else -> strings
    }
  }
  let [head_a, ..a] = nonempty(a)
  let [head_b, ..b] = nonempty(b)
  case head_a == head_b {
    True -> remove_common_path(a, b)
    False -> #(head_a, head_b)
  }
}

/// TODO
///
pub fn config(input: CommandInput) -> TaskResult {
  try toml =
    "gleam.toml"
    |> toml.parse_file

  input.args
  |> toml.decode(from: toml, expect: dynamic.dynamic)
  |> result.map(with: toml.encode_json)
}

/// TODO
/// TODO: split out `do_docs_build`, wrap in `multitask`
///
pub fn docs_build(input: CommandInput) -> TaskResult {
  assert Ok(flag.B(all)) =
    "all"
    |> flag.get_value(from: input.flags)
  let input = case all {
    True -> {
      // Prepare to build documentation for all Gleam dependencies
      assert Ok(flags) =
        "--all=false"
        |> flag.update_flags(in: input.flags)
      let toml =
        "gleam.toml"
        |> toml.parse_file
        |> result.lazy_unwrap(or: toml.new)
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
      |> list.filter(for: fn(name) { // Gleam packages only
        //
        ["./build/packages/", name, "/gleam.toml"]
        |> string.concat
        |> util.is_file })
      |> function.tap(fn(dependencies) {
        case dependencies {
          [] -> Nil
          _else -> {
            // Build documentation for the base project too
            []
            |> CommandInput(flags: flags)
            |> docs_build
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
      |> docs_build
    }
    None -> result
  }
}

/// TODO
///
pub fn docs_serve(input: CommandInput) -> TaskResult {
  try _output = docs_build(input)

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
      [rad_path, "/priv/node_modules/wonton/src/bin.js"]
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
pub fn format(input: CommandInput) -> TaskResult {
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
        |> shellout.style(with: shellout.color(["magenta"]), custom: lookups),
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
        |> user(command, _)
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
pub fn formatters_from_config() -> List(Result(Formatter, Snag)) {
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

  "gleam.toml"
  |> toml.parse_file
  |> result.lazy_unwrap(or: toml.new)
  |> toml.decode(
    get: ["rad", "formatters"],
    expect: dynamic.list(of: toml.from_dynamic),
  )
  |> result.unwrap(or: [])
  |> list.map(with: toml.decode(from: _, get: [], expect: requirements))
}

/// TODO
///
pub fn gleam(path: List(String), input: CommandInput) -> TaskResult {
  [path, util.relay_flags(input.flags), input.args]
  |> list.flatten
  |> shellout.command(run: "gleam", in: ".", opt: [LetBeStderr, LetBeStdout])
  |> result.replace("")
  |> result.replace_error(snag.new("task failed"))
}

/// Builds help dialogues for the given [`Tasks`](#Tasks) and any subtasks.
///
/// Any [`Task`](#Task) with an empty `shortdoc` field, or for which no parent
/// [`Task`](#Task) exists, is hidden from ancestor help dialogues, but can be
/// viewed directly.
///
pub fn help(tasks: Tasks, path: List(String), input: CommandInput) -> TaskResult {
  let path = case path {
    ["help"] -> input.args
    _else -> path
  }

  let tasks =
    [tasks, result.values(tasks_from_config())]
    |> list.flatten

  try task =
    tasks
    |> list.find(one_that: fn(task) { task.path == path })
    |> result.replace_error(snag.new("rad task not found"))

  // Get subtasks
  let tasks =
    tasks
    |> list.filter_map(with: fn(task) {
      let #(compare_path, subpath) =
        task.path
        |> list.split(at: list.length(path))
      case path == compare_path && list.length(subpath) == 1 && task.shortdoc != "" {
        True ->
          Task(..task, path: subpath)
          |> Ok
        False -> Error(Nil)
      }
    })

  let has_flags = task.flags != []
  let has_parameters = task.parameters != []
  let has_tasks = tasks != []

  try info = info()
  let info = Some(info)

  let description = case task.shortdoc {
    "" -> None
    _else -> {
      let description =
        [tab, task.shortdoc]
        |> string.concat
      [heading("Description"), description]
      |> string.join(with: "\n")
      |> Some
    }
  }

  let path = case path {
    [] -> None
    _else ->
      path
      |> string.join(with: " ")
      |> shellout.style(
        with: shellout.display(["bold"])
        |> map.merge(shellout.color([path_color])),
        custom: lookups,
      )
      |> Some
  }

  let subcommand = case has_tasks {
    True ->
      "<subcommand>"
      |> shellout.style(
        with: shellout.color([subcommand_color]),
        custom: lookups,
      )
      |> Some
    False -> None
  }

  let flags = case has_flags {
    True ->
      "[flags]"
      |> shellout.style(with: shellout.color([flag_color]), custom: lookups)
      |> Some
    False -> None
  }

  let parameters = case has_parameters {
    True ->
      task.parameters
      |> list.map(with: pair.first)
      |> string.join(with: " ")
      |> shellout.style(
        with: shellout.color([parameter_color]),
        custom: lookups,
      )
      |> Some
    False -> None
  }

  let usage =
    "rad"
    |> shellout.style(
      with: shellout.display(["bold"])
      |> map.merge(shellout.color(["pink"])),
      custom: lookups,
    )
    |> Some
  let usage =
    [usage, path, subcommand, flags, parameters]
    |> option.values
    |> string.join(with: " ")
    |> string.append(tab, suffix: _)
  let usage =
    [heading("Usage"), usage]
    |> string.join(with: "\n")
    |> Some

  let parameters =
    "Parameters"
    |> section(
      when: has_parameters,
      enum: task.parameters,
      with: function.identity,
      styled: shellout.color([parameter_color]),
      sorted: fn(_a, _b) { order.Eq },
    )

  let flags =
    "Flags"
    |> section(
      when: has_flags,
      enum: task.flags,
      with: fn(flag) {
        let #(name, contents) = flag
        let name =
          [flag.prefix, name]
          |> string.concat
        #(name, contents.description)
      },
      styled: shellout.color([flag_color]),
      sorted: string.compare,
    )

  let subcommands =
    "Subcommands"
    |> section(
      when: has_tasks,
      enum: tasks,
      with: fn(task) {
        let [name] = task.path
        #(name, task.shortdoc)
      },
      styled: shellout.color([subcommand_color]),
      sorted: string.compare,
    )

  [info, description, usage, parameters, flags, subcommands]
  |> option.values
  |> string.join(with: "\n\n")
  |> Ok
}

/// Gathers and formats information about `rad`.
///
pub fn info() -> TaskResult {
  // Check if `rad` is the base project or a dependency
  try toml =
    "gleam.toml"
    |> toml.parse_file
  try project_name =
    ["name"]
    |> toml.decode(from: toml, expect: dynamic.string)
  try toml = case project_name {
    "rad" -> Ok(toml)
    _else ->
      "build/packages/rad/gleam.toml"
      |> toml.parse_file
  }

  let name =
    "rad"
    |> shellout.style(
      with: shellout.display(["bold", "italic"])
      |> map.merge(shellout.color(["pink"])),
      custom: lookups,
    )
    |> Some

  let version =
    ["version"]
    |> toml.decode(from: toml, expect: dynamic.string)
    |> result.map(with: shellout.style(
      _,
      with: shellout.display(["italic"]),
      custom: lookups,
    ))
    |> option.from_result

  let description =
    ["description"]
    |> toml.decode(from: toml, expect: dynamic.string)
    |> result.map(with: shellout.style(
      _,
      with: shellout.display(["italic"])
      |> map.merge(shellout.color(["purple"])),
      custom: lookups,
    ))
    |> option.from_result

  [
    [name, version]
    |> option.values
    |> string.join(with: " ")
    |> Some,
    [Some(""), description]
    |> option.all
    |> option.map(with: string.join(_, with: tab)),
  ]
  |> option.values
  |> string.join(with: "\n")
  |> Ok
}

/// TODO
///
pub fn heading(name: String) -> String {
  name
  |> shellout.style(
    with: shellout.display(["bold"])
    |> map.merge(shellout.color([heading_color])),
    custom: lookups,
  )
}

/// TODO
///
pub fn section(
  named name: String,
  when cond: Bool,
  enum items: List(any),
  with format_fun: fn(any) -> #(String, String),
  styled style: StyleFlags,
  sorted order_by: fn(String, String) -> Order,
) -> Option(String) {
  case cond {
    True -> {
      let items =
        items
        |> list.map(with: format_fun)
      let width =
        items
        |> list.fold(
          from: 0,
          with: fn(acc, item) {
            let length = string.length(item.0)
            case length > acc {
              True -> length
              False -> acc
            }
          },
        )
      [
        heading(name),
        ..items
        |> list.map(with: fn(item) {
          let name =
            item.0
            |> string.pad_right(to: width, with: " ")
            |> shellout.style(with: style, custom: lookups)
          [tab, name, tab, item.1]
          |> string.concat
        })
        |> list.sort(order_by)
      ]
      |> string.join(with: "\n")
      |> Some
    }
    False -> None
  }
}

/// Provides multitarget support for a given [`Task`](#Task).
///
/// If multiple targets are given with the `--target` flag, the [`Task`](#Task)
/// will be run for each of them in succession.
///
/// This [`Task`](#Task) runs for all targets regardless of any failures;
/// however, all runs must succeed for this [`Task`](#Task) to succeed.
///
pub fn multitarget(
  task: fn(CommandInput) -> TaskResult,
  input: CommandInput,
) -> TaskResult {
  assert Ok(flag.LS(targets)) =
    "target"
    |> flag.get_value(from: input.flags)

  let #(oks, errors) =
    targets
    |> list.unique
    |> list.index_map(with: fn(index, target) {
      case index {
        0 -> Nil
        _else -> io.println("")
      }
      [
        "  Targeting"
        |> shellout.style(with: shellout.color(["magenta"]), custom: lookups),
        " ",
        target,
        "...",
      ]
      |> string.concat
      |> io.println
      // Run the given task
      assert Ok(flags) =
        ["--target=", target]
        |> string.concat
        |> flag.update_flags(in: input.flags)
      input.args
      |> CommandInput(flags: flags)
      |> task
      |> function.tap(fn(result) {
        case result {
          Ok(_output) -> Nil
          Error(snag) ->
            snag
            |> snag.pretty_print
            |> string.trim
            |> io.println
        }
      })
    })
    |> list.partition(with: result.is_ok)

  // Format output
  case errors {
    [] ->
      oks
      |> result.values
      |> string.join(with: "\n")
      |> Ok
    _else -> {
      io.println("")
      let errors = list.length(of: errors)
      let results =
        [errors, list.length(of: oks)]
        |> int.sum
        |> int.to_string
      let failure = case results {
        "1" -> "target"
        _else -> "targets"
      }
      [
        errors
        |> int.to_string,
        " of ",
        results,
        " ",
        failure,
        " failed",
      ]
      |> string.concat
      |> snag.new
      |> Error
    }
  }
  |> result.map(with: string.trim)
}

/// TODO
///
pub fn name(input: CommandInput) -> TaskResult {
  case input.args {
    [] -> {
      try toml =
        "gleam.toml"
        |> toml.parse_file
      ["name"]
      |> toml.decode(from: toml, expect: dynamic.string)
    }
    _else -> util.dependency(input.args)
  }
  |> result.map(with: shellout.style(
    _,
    with: util.style_flags(input.flags),
    custom: lookups,
  ))
}

/// TODO
///
pub fn origin(_input: CommandInput) -> TaskResult {
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
pub fn root(input: CommandInput) -> TaskResult {
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
        |> version
      }
      ["rad"]
      |> version
      |> result.lazy_or(fn() { version([]) })
    }
    False ->
      tasks()
      |> help([], input)
  }
}

/// TODO
///
pub fn shell(input: CommandInput) -> TaskResult {
  do_shell(input)
}

if erlang {
  fn do_shell(_input: CommandInput) -> TaskResult {
    util.refuse_erlang()
  }
}

if javascript {
  fn do_shell(input: CommandInput) -> TaskResult {
    let options = [LetBeStderr, LetBeStdout]
    let runtime = case input.args {
      [runtime, ..] -> runtime
      _else -> "erlang"
    }
    case runtime {
      "elixir" | "iex" -> {
        try toml =
          "gleam.toml"
          |> toml.parse_file
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

      "nodejs" | "node" -> {
        let script =
          [
            ["import('"],
            [rad_path, "/dist/rad_ffi.mjs"],
            ["')"],
            [".then(module => module.load_modules())"],
          ]
          |> list.flatten
          |> string.concat
        ["--interactive", "--eval", script]
        |> util.javascript_run(opt: options)
      }

      "erlang" | "erl" ->
        []
        |> util.erlang_run(opt: options)

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
pub fn tree(_input: CommandInput) -> TaskResult {
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
pub fn user(command: List(String), input: CommandInput) -> TaskResult {
  let [command, ..args] = command
  [args, util.relay_flags(input.flags), input.args]
  |> list.flatten
  |> shellout.command(run: command, in: ".", opt: [LetBeStderr, LetBeStdout])
  |> result.replace_error(snag.new("task failed"))
}

/// TODO
///
pub fn version(input: CommandInput) -> TaskResult {
  assert Ok(flag.B(bare)) =
    "bare"
    |> flag.get_value(from: input.flags)

  try toml =
    "gleam.toml"
    |> toml.parse_file

  try name = case bare {
    True -> Ok(None)
    False ->
      case input.args {
        [] ->
          ["name"]
          |> toml.decode(from: toml, expect: dynamic.string)
        _else -> util.dependency(input.args)
      }
      |> result.map(with: Some)
  }
  let name =
    name
    |> option.map(with: shellout.style(
      _,
      with: util.style_flags(input.flags),
      custom: lookups,
    ))

  try version = case input.args {
    [] ->
      ["version"]
      |> toml.decode(from: toml, expect: dynamic.string)
    _else -> util.packages(input.args)
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
pub fn watch(input: CommandInput) -> TaskResult {
  do_watch(input)
}

if erlang {
  fn do_watch(_input: CommandInput) -> TaskResult {
    util.refuse_erlang()
  }
}

if javascript {
  fn do_watch(input: CommandInput) -> TaskResult {
    let options = [LetBeStderr, LetBeStdout]
    let rad = util.which_rad()
    let flags = util.relay_flags(input.flags)
    [
      " Watching"
      |> shellout.style(with: shellout.color(["magenta"]), custom: lookups),
      " … "
      |> shellout.style(with: shellout.color(["cyan"]), custom: lookups),
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
    on: fn() -> Result(String, #(Int, String)),
    do: fn() -> Result(String, #(Int, String)),
  ) -> Result(String, Nil) =
    "../rad_ffi.mjs" "watch_loop"
}

/// TODO
///
pub fn watch_do(input: CommandInput) -> TaskResult {
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
        |> shellout.style(with: shellout.color(["magenta"]), custom: lookups),
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

  let gleam_test = gleam(["test"], _)
  [#("target", target_flag)]
  |> map.from_list
  |> CommandInput(args: input.args)
  |> multitarget(gleam_test, _)
}
