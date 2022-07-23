//// TODO
////

import gleam/bool
import gleam/dynamic
import gleam/function
import gleam/io
import gleam/list
import gleam/map
import gleam/result
import gleam/string
import glint.{Help, Out}
import glint/flag
import rad/task
import rad/toml
import rad/util
import rad/workbook.{Workbook}
import shellout.{LetBeStderr, LetBeStdout}
import snag.{Snag}

if erlang {
  import gleam/dynamic.{Dynamic}
  import gleam/erlang/atom.{Atom}
}

/// Runs `rad`, a flexible task runner companion for the `gleam` build manager.
///
/// Specify a different workbook `module` in the `[rad]` table of your
/// `gleam.toml` config to have `rad` run your workbook's `main` function, in
/// which you can call [`do_main`](#do_main) to extend `rad` with your own
/// [`Workbook`](rad/workbook.html#Workbook).
///
pub fn main() -> Nil {
  let toml =
    "gleam.toml"
    |> toml.parse_file
    |> result.lazy_unwrap(or: toml.new)

  // Determine runtime
  let with =
    ["rad", "with"]
    |> toml.decode(from: toml, expect: dynamic.string)
    |> result.unwrap(or: "javascript")
  assert Ok(Out(with)) =
    glint.new()
    |> glint.add_command(
      at: [],
      do: fn(input) {
        assert Ok(flag.S(with)) =
          "with"
          |> flag.get_value(from: input.flags)
        with
      },
      with: [flag.string(called: "with", default: with, explained: "")],
      described: "",
      used: "",
    )
    |> glint.execute(arguments(Global))

  // Try to run any task `with` a given runtime
  rad_run(
    with,
    fn() {
      ["rad", "module"]
      |> toml.decode(from: toml, expect: dynamic.string)
      |> result.unwrap(or: "rad/workbook/standard")
      |> gleam_run
    },
  )
}

/// Applies arguments from the command line to the given
/// [`Workbook`](rad/workbook.html#Workbook), then processes the output and exits.
///
/// You can merge `rad`'s
/// [`standard.workbook`](rad/workbook/standard.html#workbook) with your own, or
/// replace it entirely.
///
/// See [`main`](#main) for more info.
///
pub fn do_main(workbook: Workbook) -> Nil {
  task.tasks_from_config()
  |> list.map(with: result.map_error(_, with: fn(snag) {
    Snag(..snag, issue: "invalid `[[rad.tasks]]` in `gleam.toml`")
    |> util.snag_pretty_print
    |> string.trim
    |> string.append(suffix: "\n")
    |> io.println
  }))
  |> result.values
  |> workbook.tasks(into: workbook)
  |> map.fold(
    from: glint.new(),
    with: fn(acc, path, task) {
      acc
      |> glint.add_command(
        at: path,
        do: task.run(_, task),
        with: task.flags,
        described: task.shortdoc,
        used: ["rad", ..task.path]
        |> string.join(with: " ")
        |> string.append(suffix: " <SUBCOMMAND> <FLAGS>"),
      )
    },
  )
  |> glint.execute(arguments(Normal))
  |> result.map(with: fn(output) {
    case output {
      Out(result) -> result
      Help(string) -> Ok(string)
    }
  })
  |> result.flatten
  |> end_task
}

type Scope {
  Global
  Normal
}

fn arguments(scope: Scope) -> List(String) {
  let filter = string.starts_with(_, "--with=")
  let arguments =
    shellout.arguments()
    |> list.filter(for: case scope {
      Global -> filter
      Normal ->
        filter
        |> function.compose(bool.negate)
    })
  case scope {
    Global -> arguments
    Normal -> {
      // Help flag uses rad's workbook.help
      let #(arguments, is_help) =
        arguments
        |> list.fold(
          from: #([], False),
          with: fn(acc, argument) {
            let #(arguments, is_help) = acc
            case argument {
              "--help" | "--help=true" -> #(arguments, True)
              "--help=false" -> #(arguments, False)
              _else -> #([argument, ..arguments], is_help)
            }
          },
        )
      let arguments =
        arguments
        |> list.reverse
      case is_help {
        True -> ["help", ..arguments]
        False -> arguments
      }
    }
  }
}

fn end_task(result: Result(String, Snag)) -> Nil {
  case result {
    Ok(output) -> {
      case output {
        "" -> output
        _else ->
          [string.trim(output), "\n"]
          |> string.concat
      }
      |> io.print
      shellout.exit(0)
    }
    Error(error) -> {
      error
      |> util.snag_pretty_print
      |> io.print
      shellout.exit(1)
    }
  }
}

fn gleam_run(module: String) -> Nil {
  do_gleam_run(module)
}

if erlang {
  fn do_gleam_run(module: String) -> Nil {
    module
    |> string.replace(each: "/", with: "@")
    |> atom.create_from_string
    |> erlang_gleam_run
    Nil
  }

  external fn erlang_gleam_run(Atom) -> Dynamic =
    "gleam@@main" "run"
}

if javascript {
  external fn do_gleam_run(String) -> Nil =
    "./rad_ffi.mjs" "gleam_run"
}

fn is_running(target: String) -> Bool {
  target
  |> string.lowercase
  |> do_is_running
}

if erlang {
  fn do_is_running(target: String) -> Bool {
    case target {
      "erlang" -> True
      _else -> False
    }
  }
}

if javascript {
  fn do_is_running(target: String) -> Bool {
    case target {
      "javascript" -> True
      _else -> False
    }
  }
}

fn rad_run(with: String, fun: fn() -> Nil) -> Nil {
  case is_running(with), with {
    True, _any -> fun()

    _else_if, "erlang" ->
      {
        let options = [LetBeStderr, LetBeStdout]
        try _output = case
          util.file_exists("./build/dev/erlang/rad/ebin/rad.app")
        {
          True -> Ok("")
          False ->
            // Build `rad` for Erlang
            ["build", "--target=erlang"]
            |> shellout.command(run: "gleam", in: ".", opt: options)
            |> result.replace_error(snag.new("failed to run task"))
        }
        // Run `rad` with Erlang
        [
          ["-noshell"],
          ["-eval", "gleam@@main:run(rad)"],
          ["-extra", ..shellout.arguments()],
        ]
        |> list.flatten
        |> util.erlang_run(opt: options)
      }
      |> end_task

    _else_if, "javascript" ->
      [
        ["--title=rad"],
        [
          "--eval=import('./build/dev/javascript/rad/dist/rad.mjs').then(module => module.main())",
        ],
        ["--", ..shellout.arguments()],
      ]
      |> list.flatten
      |> util.javascript_run(opt: [LetBeStderr, LetBeStdout])
      |> end_task

    _else, _any ->
      ["unknown target `", with, "`"]
      |> string.concat
      |> snag.error
      |> snag.context("failed to run task")
      |> end_task
  }
}
