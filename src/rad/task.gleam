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
import glint/flag.{Flag}
import rad/util.{rad_path}
import shellout.{LetBeStderr, LetBeStdout, Lookups}
import snag.{Snag}

/// TODO
///
pub const have_version = ["gleam.toml", "README.md"]

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
pub type Task(a) {
  Task(
    path: List(String),
    run: fn(CommandInput) -> a,
    flags: List(Flag),
    shortdoc: String,
    parameters: List(#(String, String)),
  )
}

/// TODO
///
pub type Tasks =
  List(Task(Result(String, Snag)))

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

  let target = case util.toml(
    read: "gleam.toml",
    get: ["target"],
    expect: dynamic.string,
  ) {
    Ok(target) -> target
    Error(_message) -> "erlang"
  }
  let target_flags = [
    flag.string(
      called: "target",
      default: target,
      explained: "The platform to target",
    ),
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
      run: gleam(["build"], _),
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
      //flags: [flag.bool("check", False), flag.bool("stdin", False)],
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
      run: gleam(["test"], _),
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
pub fn tasks_from_config() -> Tasks {
  let list_string = fn(key) {
    let snag =
      ["expected `", key, "` in `[[rad.tasks]]` of type `List(String)`"]
      |> string.concat
      |> snag.new
    function.compose(
      dynamic.field(key, dynamic.list(dynamic.string)),
      result.replace_error(_, snag),
    )
  }
  assert Ok(tasks) =
    util.toml(
      read: "gleam.toml",
      get: ["rad", "tasks"],
      expect: dynamic.shallow_list,
    )
    |> result.map(with: list.map(_, with: fn(item) {
      // Require `path` and `run` for every task
      //
      let path =
        item
        |> list_string("path")
      let run =
        item
        |> list_string("run")
      let #(path, run) = case path, run {
        Ok(path), Ok(run) -> #(path, run)
        _path, _run -> {
          case path, run {
            Error(path), Ok(_run) -> [path.issue]
            Ok(_path), Error(run) -> [run.issue]
            Error(path), Error(run) -> [path.issue, run.issue]
          }
          |> Snag(issue: "malformed task in `gleam.toml`")
          |> snag.pretty_print
          |> io.print
          shellout.exit(1)
          #([], [])
        }
      }
      let shortdoc = case item
      |> dynamic.field("shortdoc", dynamic.string) {
        Ok(shortdoc) -> shortdoc
        Error(_decode_error) -> ""
      }
      Task(
        path: path,
        run: user(run, _),
        flags: [],
        shortdoc: shortdoc,
        parameters: [],
      )
    }))
    |> result.or(Ok([]))
  tasks
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
    case strings == [] {
      False -> strings
      True -> [""]
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
pub fn config(input: CommandInput) -> Result(String, Snag) {
  util.toml(read: "gleam.toml", get: input.args, expect: dynamic.dynamic)
  |> result.map(with: util.json_encode)
}

/// TODO
///
pub fn docs_build(input: CommandInput) -> Result(String, Snag) {
  assert Ok(flag.B(all)) = flag.get_value(from: input.flags, for: "all")
  let input = case all {
    False -> input
    True -> {
      // Prepare to build documentation for all Gleam dependencies
      //
      let flags =
        False
        |> flag.B
        |> flag.Contents(description: "")
        |> map.insert(into: input.flags, for: "all")
      let input =
        [["dependencies"], ["dev-dependencies"]]
        |> list.map(with: util.toml(
          read: "gleam.toml",
          get: _,
          expect: util.dynamic_object(dynamic.string, dynamic.string),
        ))
        |> result.values
        |> list.map(with: map.keys)
        |> list.flatten
        |> list.unique
        |> list.filter(for: fn(name) {
          ["./build/packages/", name, "/gleam.toml"]
          |> string.concat
          |> util.is_file
        })
        |> CommandInput(flags: flags)
      case input.args == [] {
        False -> {
          // Build documentation for the base project
          //
          []
          |> CommandInput(flags: flags)
          |> docs_build
          io.println("")
        }
        True -> Nil
      }
      input
    }
  }
  let args = input.args
  let extra_args = case args {
    [_, ..args] if args != [] -> Some(args)
    _args -> None
  }
  try #(name, path) = case extra_args {
    None if args == [] ->
      #("", ".")
      |> Ok
    _args ->
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
        _path -> {
          let new_path = string.concat(["./build/dev/docs/", name])
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
pub fn docs_serve(input: CommandInput) -> Result(String, Snag) {
  try _output = docs_build(input)

  io.println("")

  assert Ok(flag.S(host)) = flag.get_value(from: input.flags, for: "host")
  assert Ok(flags) = case host == "localhost" {
    True -> flag.update_flags(in: input.flags, with: "--host=127.0.0.1")
    False -> Ok(input.flags)
  }

  [
    [string.concat([rad_path, "/priv/node_modules/wonton/src/bin.js"])],
    util.relay_flags(flags),
    ["--", "./build/dev/docs"],
  ]
  |> list.flatten
  |> util.javascript_run(opt: [LetBeStderr, LetBeStdout])
  |> result.replace("")
}

/// TODO
///
pub fn format(input: CommandInput) -> Result(String, Snag) {
  // TODO run all regardless of errors, layer snags
  gleam(["format"], input)
  |> result.then(apply: fn(_output) {
    shellout.command(// TODO config override commands
      // TODO rome
      run: string.concat([rad_path, "/priv/node_modules/.bin/prettier"]), with: list.flatten([
        ["--config", string.concat([rad_path, "/priv/.prettierrc.toml"])],
        ["--no-error-on-unmatched-pattern"],
        // TODO
        //"--check",
        ["src"],
      ]), in: ".", opt: [LetBeStderr, LetBeStdout])
    |> result.replace_error(snag.new("javascript formatting issue"))
  })
}

/// TODO
///
pub fn gleam(path: List(String), input: CommandInput) -> Result(String, Snag) {
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
pub fn help(
  tasks: Tasks,
  path: List(String),
  input: CommandInput,
) -> Result(String, Snag) {
  let heading = shellout.style(
    _,
    with: shellout.display(["bold"])
    |> map.merge(shellout.color([heading_color])),
    custom: lookups,
  )

  let max_width = fn(items: List(a), length_fun: fn(a) -> Int) -> Int {
    items
    |> list.fold(
      from: 0,
      with: fn(acc, item) {
        let length = length_fun(item)
        case length > acc {
          False -> acc
          True -> length
        }
      },
    )
  }

  let drop_empty_strings = list.filter(_, for: fn(string) { string != "" })

  let path = case path {
    ["help"] -> input.args
    _path -> path
  }

  let tasks = list.flatten([tasks, tasks_from_config()])

  try task =
    tasks
    |> list.find(one_that: fn(task) { task.path == path })
    |> result.replace_error(snag.new("rad task not found"))

  let has_flags = task.flags != []
  let has_parameters = task.parameters != []

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

  let has_tasks = tasks != []

  let width =
    tasks
    |> max_width(fn(task) {
      task.path
      |> string.join(with: " ")
      |> string.length
    })

  try info = info()

  let description = case task.shortdoc != "" {
    True -> {
      let description =
        [tab, task.shortdoc]
        |> string.concat
      [heading("Description"), description]
      |> string.join(with: "\n")
    }
    False -> ""
  }

  let path = case path != [] {
    True ->
      path
      |> string.join(with: " ")
      |> shellout.style(
        with: shellout.display(["bold"])
        |> map.merge(shellout.color([path_color])),
        custom: lookups,
      )
    False -> ""
  }

  let subcommand = case has_tasks {
    True ->
      "<subcommand>"
      |> shellout.style(
        with: shellout.color([subcommand_color]),
        custom: lookups,
      )
    False -> ""
  }

  let flags = case has_flags {
    True ->
      "[flags]"
      |> shellout.style(with: shellout.color([flag_color]), custom: lookups)
    False -> ""
  }

  let parameters = case has_parameters {
    True ->
      task.parameters
      |> list.map(pair.first)
      |> string.join(with: " ")
      |> shellout.style(
        with: shellout.color([parameter_color]),
        custom: lookups,
      )
    False -> ""
  }

  let usage =
    "rad"
    |> shellout.style(
      with: shellout.display(["bold"])
      |> map.merge(shellout.color(["pink"])),
      custom: lookups,
    )
  let usage =
    [usage, path, subcommand, flags, parameters]
    |> drop_empty_strings
    |> string.join(with: " ")
    |> string.append(tab, suffix: _)
  let usage =
    [heading("Usage"), usage]
    |> string.join(with: "\n")

  let parameters = case has_parameters {
    True -> {
      let width =
        pair.first
        |> function.compose(string.length)
        |> max_width(task.parameters, _)
      [
        heading("Parameters"),
        ..task.parameters
        |> list.map(with: fn(parameter) {
          let #(name, doc) = parameter
          let name =
            name
            |> string.pad_right(to: width, with: " ")
            |> shellout.style(
              with: shellout.color([parameter_color]),
              custom: lookups,
            )
          [tab, name, tab, doc]
          |> string.concat
        })
      ]
      |> string.join(with: "\n")
    }
    False -> ""
  }

  let flags = case has_flags {
    True -> {
      let width =
        task.flags
        |> max_width(fn(flag) {
          string.length(flag.0) + string.length(flag.prefix)
        })
      [
        heading("Flags"),
        ..task.flags
        |> list.map(with: fn(flag) {
          let #(name, contents) = flag
          let name =
            [flag.prefix, name]
            |> string.concat
            |> string.pad_right(to: width, with: " ")
            |> shellout.style(
              with: shellout.color([flag_color]),
              custom: lookups,
            )
          [tab, name, tab, contents.description]
          |> string.concat
        })
        |> list.sort(by: string.compare)
      ]
      |> string.join(with: "\n")
    }
    False -> ""
  }

  let subcommands = case has_tasks {
    True ->
      [
        heading("Subcommands"),
        ..tasks
        |> list.map(with: fn(task) {
          let [path] = task.path
          let path =
            path
            |> string.pad_right(to: width, with: " ")
            |> shellout.style(
              with: shellout.color([subcommand_color]),
              custom: lookups,
            )
          [tab, path, tab, task.shortdoc]
          |> string.concat
        })
        |> list.sort(string.compare)
      ]
      |> string.join(with: "\n")
    False -> ""
  }

  [info, description, usage, parameters, flags, subcommands]
  |> drop_empty_strings
  |> string.join(with: "\n\n")
  |> Ok
}

/// Gathers and formats information about `rad`.
///
pub fn info() -> Result(String, Snag) {
  let file = "gleam.toml"
  try config =
    file
    |> util.toml_read_file
    |> result.map_error(with: fn(_nil) {
      ["failed to read `", file, "`"]
      |> string.concat
      |> snag.new
    })
  try project =
    config
    |> util.toml_get(["name"])
    |> result.replace_error(snag.new("project name not found"))
    |> result.then(apply: function.compose(
      dynamic.string,
      result.replace_error(_, snag.new("project name is not a string")),
    ))

  try config = case project {
    "rad" -> Ok(config)
    _name -> {
      let file = "build/packages/rad/gleam.toml"
      file
      |> util.toml_read_file
      |> result.map_error(with: fn(_nil) {
        ["failed to read `", file, "`"]
        |> string.concat
        |> snag.new
      })
    }
  }

  try version =
    config
    |> util.toml_get(["version"])
    |> result.replace_error(snag.new("rad version not found"))
    |> result.then(apply: function.compose(
      dynamic.string,
      result.replace_error(_, snag.new("rad version is not a string")),
    ))

  try description =
    config
    |> util.toml_get(["description"])
    |> result.replace_error(snag.new("rad description not found"))
    |> result.then(apply: function.compose(
      dynamic.string,
      result.replace_error(_, snag.new("rad description is not a string")),
    ))

  [
    string.concat([
      "rad"
      |> shellout.style(
        with: shellout.display(["bold", "italic"])
        |> map.merge(shellout.color(["pink"])),
        custom: lookups,
      ),
      " ",
      version
      |> shellout.style(with: shellout.display(["italic"]), custom: lookups),
    ]),
    string.concat([
      tab,
      description
      |> shellout.style(
        with: shellout.display(["italic"])
        |> map.merge(shellout.color(["purple"])),
        custom: lookups,
      ),
    ]),
  ]
  |> string.join(with: "\n")
  |> Ok
}

/// TODO
///
pub fn name(input: CommandInput) -> Result(String, Snag) {
  case input.args {
    [] ->
      ["name"]
      |> util.toml(read: "gleam.toml", expect: dynamic.string)
    _args -> {
      try name = util.dependency(input.args)
      Ok(name)
    }
  }
  |> result.map(with: shellout.style(
    _,
    with: util.style_flags(input.flags),
    custom: lookups,
  ))
}

/// TODO
///
pub fn origin(_input: CommandInput) -> Result(String, Snag) {
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
pub fn root(input: CommandInput) -> Result(String, Snag) {
  assert Ok(flag.B(ver)) = flag.get_value(from: input.flags, for: "version")
  case ver {
    False -> help(tasks(), [], input)
    True -> {
      let flags =
        flag.build_map([
          #("bare", flag.Contents(value: flag.B(False), description: "")),
        ])
      let version = fn(args) {
        args
        |> CommandInput(flags: flags)
        |> version
      }
      ["rad"]
      |> version
      |> result.lazy_or(fn() { version([]) })
    }
  }
}

/// TODO
///
pub fn shell(input: CommandInput) -> Result(String, Snag) {
  do_shell(input)
}

if erlang {
  fn do_shell(_input: CommandInput) -> Result(String, Snag) {
    util.refuse_erlang()
  }
}

if javascript {
  fn do_shell(input: CommandInput) -> Result(String, Snag) {
    let options = [LetBeStderr, LetBeStdout]
    let runtime = case input.args {
      [] -> "erlang"
      [runtime, ..] -> runtime
    }
    case runtime {
      "elixir" | "iex" ->
        ["name"]
        |> util.toml(read: "gleam.toml", expect: dynamic.string)
        |> result.then(apply: fn(name) {
          util.ebin_paths()
          |> result.replace_error(snag.new("failed to find `ebin` paths"))
          |> result.map(with: fn(ebins) { #(name, ebins) })
        })
        |> result.then(apply: fn(acc) {
          let #(name, ebins) = acc
          shellout.command(
            run: "iex",
            with: list.flatten([
              ["--app", name],
              ["--erl", string.join(["-pa", ..ebins], with: " ")],
            ]),
            in: ".",
            opt: options,
          )
          |> result.replace_error(snag.new("failed to run `iex` shell"))
        })

      "nodejs" | "node" ->
        util.javascript_run(
          with: [
            "--interactive",
            [
              ["--eval=import('"],
              [rad_path, "/dist/rad_ffi.mjs"],
              ["')"],
              [".then(module => module.load_modules())"],
            ]
            |> list.flatten
            |> string.concat,
          ],
          opt: options,
        )

      "erlang" | "erl" -> util.erlang_run(with: [], opt: options)

      _runtime ->
        ["unsupported runtime `", runtime, "`"]
        |> string.concat
        |> snag.new
        |> Error
    }
  }
}

/// TODO
///
pub fn tree(_input: CommandInput) -> Result(String, Snag) {
  assert Ok(working_directory) = util.working_directory()
  let result =
    shellout.command(
      run: "exa",
      with: [
        "--all",
        "--color=always",
        "--git-ignore",
        string.concat(["--ignore-glob=", ignore_glob]),
        "--long",
        "--git",
        "--no-filesize",
        "--no-permissions",
        "--no-user",
        "--no-time",
        "--tree",
        working_directory,
      ],
      in: ".",
      opt: [],
    )
    |> result.replace_error(snag.new("command `exa` not found"))
  case result {
    Error(error) ->
      shellout.command(
        run: "tree",
        with: list.flatten([
          ["-a"],
          ["-C"],
          ["-I", ignore_glob],
          ["--matchdirs"],
          ["--noreport"],
          [working_directory],
        ]),
        in: ".",
        opt: [],
      )
      |> result.replace_error(snag.layer(error, "command `tree` not found"))
    Ok(_output) -> result
  }
  |> result.map_error(with: function.compose(
    snag.layer(_, "failed to find a known tree command"),
    snag.layer(_, "failed to run task"),
  ))
}

/// TODO
///
pub fn user(command: List(String), input: CommandInput) -> Result(String, Snag) {
  let [command, ..args] = command
  shellout.command(
    run: command,
    with: list.flatten([args, util.relay_flags(input.flags), input.args]),
    in: ".",
    opt: [LetBeStderr, LetBeStdout],
  )
  |> result.replace_error(snag.new("task failed"))
}

/// TODO
///
pub fn version(input: CommandInput) -> Result(String, Snag) {
  assert Ok(flag.B(bare)) = flag.get_value(from: input.flags, for: "bare")
  try name = case bare {
    False ->
      input
      |> name
      |> result.map(with: string.append(to: _, suffix: " "))
    True -> Ok("")
  }
  case input.args {
    [] ->
      ["version"]
      |> util.toml(read: "gleam.toml", expect: dynamic.string)
    path -> util.packages(path)
  }
  |> result.map(with: string.append(to: name, suffix: _))
}

/// TODO
///
pub fn watch(input: CommandInput) -> Result(String, Snag) {
  do_watch(input)
}

if erlang {
  fn do_watch(_input: CommandInput) -> Result(String, Snag) {
    util.refuse_erlang()
  }
}

if javascript {
  fn do_watch(input: CommandInput) -> Result(String, Snag) {
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
      shellout.command(
        run: "watchexec",
        with: list.flatten([
          ignore_glob
          |> string.split(on: "|")
          |> list.map(with: fn(directory) {
            string.concat(["--ignore=**/", directory, "/**"])
          }),
          ["--postpone"],
          ["--watch-when-idle"],
          ["--", rad, "watch", "do", ..flags],
        ]),
        in: ".",
        opt: options,
      )
      |> result.replace_error(snag.new("command `watchexec` not found"))
    case result {
      Error(error) ->
        watch_loop(
          on: fn() {
            shellout.command(
              run: "inotifywait",
              with: list.flatten([
                ["--event", "create"],
                ["--event", "delete"],
                ["--event", "modify"],
                ["--event", "move"],
                [
                  "--exclude",
                  string.concat(["^[./\\\\]*(", ignore_glob, ")([/\\\\].*)*$"]),
                ],
                ["-qq"],
                ["--recursive"],
                ["."],
              ]),
              in: ".",
              opt: options,
            )
          },
          do: fn() {
            shellout.command(
              run: rad,
              with: ["watch", "do", ..flags],
              in: ".",
              opt: options,
            )
          },
        )
        |> result.replace_error(snag.layer(
          error,
          "command `inotifywait` not found",
        ))
      Ok(_output) -> result
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
pub fn watch_do(input: CommandInput) -> Result(String, Snag) {
  let options = [LetBeStderr, LetBeStdout]
  assert Ok(flag.B(no_docs)) = flag.get_value(from: input.flags, for: "no-docs")
  assert Ok(flag.I(port)) = flag.get_value(from: input.flags, for: "port")
  assert Ok(flag.S(target)) = flag.get_value(from: input.flags, for: "target")
  io.println("")
  case no_docs {
    False -> {
      [
        " Generating"
        |> shellout.style(with: shellout.color(["magenta"]), custom: lookups),
        "documentation",
      ]
      |> string.join(with: " ")
      |> io.println
      let _result =
        shellout.command(
          run: "gleam",
          with: ["docs", "build"],
          in: ".",
          opt: [],
        )
      // Live reload docs
      ["http://localhost:", int.to_string(port), "/wonton-update"]
      |> string.concat
      |> util.ping
      Nil
    }
    True -> Nil
  }
  shellout.command(
    run: "gleam",
    with: ["test", string.concat(["--target=", target])],
    in: ".",
    opt: options,
  )
  |> result.replace("")
  |> result.replace_error(snag.new("test failed"))
}
