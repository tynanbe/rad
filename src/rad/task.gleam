import gleam/dynamic
import gleam/function
import gleam/int
import gleam/list
import gleam/map
import gleam/pair
import gleam/result
import gleam/string
import glint.{CommandInput}
import glint/flag.{Flag}
import rad/util
import shellout.{LetBeStderr, LetBeStdout, Lookups, StyleFlags}
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

const rad_path = "./build/dev/javascript/rad"

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

  let target = case util.toml(read: "gleam.toml", get: ["target"]) {
    Ok(target) -> target
    _ -> "erlang"
  }
  let target_flags = [
    flag.string(
      called: "target",
      default: target,
      explained: "The platform to target",
    ),
  ]

  [
    Task(
      path: [],
      run: help(tasks(), [], _),
      flags: [],
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
      shortdoc: "Read project config values",
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
      run: gleam(["docs", "build"], _),
      flags: [],
      shortdoc: "Render HTML documentation",
      parameters: [],
    ),
    Task(
      path: ["docs", "serve"],
      run: docs_serve,
      flags: [
        flag.int(
          called: "port",
          default: 3000,
          explained: "Change the port (default 3000)",
        ),
      ],
      shortdoc: "Serve HTML documentation",
      parameters: [],
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
      flags: target_flags,
      shortdoc: "Automate the project tests",
      parameters: [],
    ),
  ]
}

/// TODO
///
pub fn config(input: CommandInput) -> Result(String, Snag) {
  util.toml(read: "gleam.toml", get: input.args)
}

/// TODO
///
pub fn docs_serve(input: CommandInput) -> Result(String, Snag) {
  assert Ok(flag.I(port)) = flag.get_value(from: input.flags, for: "port")
  shellout.command(
    // TODO replace with wonton
    run: string.concat([rad_path, "/priv/node_modules/.bin/derver"]),
    with: [
      // TODO --no-watch, handle with rad watch?
      string.concat(["--port=", int.to_string(port)]),
      "./build/dev/docs/rad",
    ],
    in: ".",
    opt: [LetBeStderr, LetBeStdout],
  )
  |> result.replace_error(snag.new("task failed"))
}

/// TODO
///
pub fn format(input: CommandInput) -> Result(String, Snag) {
  // TODO run all, layer snags
  gleam(["format"], input)
  |> result.then(apply: fn(_) {
    shellout.command(
      // TODO config override commands
      run: string.concat([rad_path, "/priv/node_modules/.bin/prettier"]),
      with: list.flatten([
        ["--config", string.concat([rad_path, "/priv/.prettierrc.toml"])],
        ["--no-error-on-unmatched-pattern"],
        // TODO
        //"--check",
        ["src"],
      ]),
      in: ".",
      opt: [LetBeStderr, LetBeStdout],
    )
    |> result.replace_error(snag.new("javascript formatting issue"))
  })
}

/// TODO
///
pub fn gleam(path: List(String), input: CommandInput) -> Result(String, Snag) {
  let flags =
    input.flags
    |> map.to_list
    |> list.filter_map(with: fn(flag) {
      let #(key, flag.Contents(value: value, ..)) = flag
      case value {
        flag.S(value) ->
          ["--", key, "=", value]
          |> string.concat
          |> Ok
        flag.B(value) if value -> Ok(string.concat(["--", key]))
        _ -> Error(Nil)
      }
    })
  [path, flags, input.args]
  |> list.flatten
  |> shellout.command(run: "gleam", in: ".", opt: [LetBeStderr, LetBeStdout])
  |> result.map(with: fn(_) { "" })
  |> result.replace_error(snag.new("task failed"))
}

/// TODO
///
pub fn info() -> Result(String, Snag) {
  let file = "gleam.toml"
  try config =
    file
    |> util.toml_read_file
    |> result.replace_error(snag.new(string.concat([
      "failed to read `",
      file,
      "`",
    ])))
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
    _ -> {
      let file = "build/packages/rad/gleam.toml"
      file
      |> util.toml_read_file
      |> result.replace_error(snag.new(string.concat([
        "failed to read `",
        file,
        "`",
      ])))
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
    _ -> path
  }

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
      case path == compare_path && list.length(subpath) == 1 {
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
      ]
      |> string.join(with: "\n")
    False -> ""
  }

  [info, description, usage, parameters, flags, subcommands]
  |> drop_empty_strings
  |> string.join(with: "\n\n")
  |> Ok
}

/// TODO
///
pub fn name(input: CommandInput) -> Result(String, Snag) {
  case input.args {
    [] ->
      CommandInput(..input, args: ["name"])
      |> config
    path ->
      path
      |> util.packages
      |> result.map(with: fn(_) {
        assert [name] = path
        name
      })
  }
  |> result.map(with: shellout.style(
    _,
    with: style_flags(input.flags),
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
pub fn shell(input: CommandInput) -> Result(String, Snag) {
  do_shell(input)
}

if erlang {
  fn do_shell(_input: CommandInput) -> Result(String, Snag) {
    refuse_erlang()
  }
}

if javascript {
  fn do_shell(input: CommandInput) -> Result(String, Snag) {
    let runtime = case input.args {
      [] -> "erlang"
      [runtime, ..] -> runtime
    }
    case runtime {
      "elixir" | "iex" ->
        CommandInput(..input, args: ["name"])
        |> config
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
            opt: [LetBeStderr, LetBeStdout],
          )
          |> result.replace_error(snag.new("failed to run `iex` shell"))
        })

      "nodejs" | "node" ->
        util.javascript_run([
          "--interactive",
          string.concat([
            "--eval=import('",
            rad_path,
            "/dist/rad_ffi.mjs')",
            ".then(module => module.load_modules())",
          ]),
        ])

      "erlang" | "erl" -> util.erlang_run([])

      _ ->
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
    _ -> result
  }
  |> result.map_error(with: function.compose(
    snag.layer(_, "failed to find a known tree command"),
    snag.layer(_, "failed to run task"),
  ))
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
      CommandInput(..input, args: ["version"])
      |> config
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
    refuse_erlang()
  }
}

if javascript {
  fn do_watch(input: CommandInput) -> Result(String, Snag) {
    let options = [LetBeStderr, LetBeStdout]
    assert Ok(flag.S(target)) = flag.get_value(from: input.flags, for: "target")
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
          ["--", "gleam", "test", string.concat(["--target=", target])],
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
              run: "gleam",
              with: ["test", string.concat(["--target=", target])],
              in: ".",
              opt: options,
            )
          },
        )
        |> result.replace_error(snag.layer(
          error,
          "command `inotifywait` not found",
        ))
      _ -> result
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
pub fn style_flags(flags: flag.Map) -> StyleFlags {
  flags
  |> map.filter(for: fn(_key, contents) {
    let flag.Contents(value: value, ..) = contents
    case value {
      flag.LS(_) -> True
      _ -> False
    }
  })
  |> map.map_values(with: fn(_key, contents) {
    let flag.Contents(value: value, ..) = contents
    assert flag.LS(value) = value
    value
  })
}

if erlang {
  fn refuse_erlang() -> Result(String, Snag) {
    snag.error("task cannot be run with erlang")
    |> snag.context("failed to run task")
  }
}
