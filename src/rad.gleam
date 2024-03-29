import gleam/dict
import gleam/dynamic
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glint.{type CommandInput, Help, Out}
import glint/flag
import rad/task
import rad/toml
import rad/util
import rad/workbook.{type Workbook}
import shellout.{LetBeStderr, LetBeStdout}
import snag.{type Snag, Snag}

const default_workbook = "rad/workbook/standard"

/// Runs `rad`, a flexible task runner companion for the `gleam` build manager.
///
/// Specify a different `workbook` module in the `[rad]` table of your project's
/// `gleam.toml` configuration file to have `rad` run your workbook's `main`
/// function, in which you can call [`do_main`](#do_main) to extend `rad` with
/// your own [`Workbook`](rad/workbook.html#Workbook).
///
pub fn main() -> Nil {
  let config =
    "gleam.toml"
    |> toml.parse_file
    |> result.lazy_unwrap(or: toml.new)

  // Determine runtime
  let with =
    ["rad", "with"]
    |> toml.decode(from: config, expect: dynamic.string)
    |> result.unwrap(or: "javascript")
  let assert Ok(Out(with)) =
    glint.new()
    |> glint.add(
      at: [],
      do: fn(input: CommandInput) {
          "with"
          |> flag.get_string(from: input.flags)
          |> result.unwrap(or: with)
        }
        |> glint.command
        |> glint.flag(
          at: "with",
          of: flag.string()
            |> flag.default(of: with),
        ),
    )
    |> glint.execute(arguments(Global))

  let assert Ok(package) =
    ["name"]
    |> toml.decode(from: config, expect: dynamic.string)

  // Try to run any task `with` a given runtime
  use <- rad_run(package, with)
  ["rad", "workbook"]
  |> toml.decode(from: config, expect: dynamic.string)
  |> result.unwrap(
    or: case with {
      "javascript" -> "../rad/"
      _else -> ""
    }
    <> default_workbook,
  )
  |> gleam_run(package, _)
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
  |> dict.fold(from: glint.new(), with: fn(acc, path, task) {
    acc
    |> glint.add(
      at: path,
      do: task.run(_, task)
        |> glint.command
        |> glint.flags(with: task.flags)
        |> glint.description(task.shortdoc),
    )
  })
  |> glint.execute(arguments(Normal))
  |> result.map(with: fn(output) {
    case output {
      Out(result) -> result
      Help(string) -> Ok(string)
    }
  })
  |> result.map_error(with: snag.new)
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
    start_arguments()
    |> list.filter(keeping: case scope {
      Global -> filter
      Normal -> fn(arg) { !filter(arg) }
    })
  case scope {
    Global -> arguments
    Normal -> {
      // Help flag uses rad's workbook.help
      let #(arguments, is_help) =
        arguments
        |> list.fold(from: #([], False), with: fn(acc, argument) {
          let #(arguments, is_help) = acc
          case argument {
            "--help" | "--help=true" -> #(arguments, True)
            "--help=false" -> #(arguments, False)
            _else -> #([argument, ..arguments], is_help)
          }
        })
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

@external(javascript, "./rad_ffi.mjs", "start_arguments")
fn start_arguments() -> List(String) {
  shellout.arguments()
}

fn end_task(result: Result(String, Snag)) -> Nil {
  case result {
    Ok(output) -> {
      case output {
        "" -> output
        _else -> string.trim(output) <> "\n"
      }
      |> io.print
      shellout.exit(0)
    }
    Error(snag) -> {
      snag
      |> util.snag_pretty_print
      |> io.print
      shellout.exit(1)
    }
  }
}

fn rad_run(package: String, with: String, fun: fn() -> Nil) -> Nil {
  case is_running(with), with {
    True, _any -> fun()

    _else_if, "erlang" ->
      {
        use _output <- result.try(case
          util.file_exists("./build/dev/erlang/rad/ebin/rad.app")
        {
          True -> Ok("")
          False -> gleam_build("erlang")
        })
        // Run `rad` with Erlang
        [
          ["-noshell"],
          ["-eval", package <> "@@main:run(rad)"],
          ["-extra", ..start_arguments()],
        ]
        |> list.concat
        |> util.erlang_run(opt: [LetBeStderr, LetBeStdout])
      }
      |> end_task

    _else_if, "javascript" -> {
      let script =
        "import('./build/dev/javascript/rad/rad.mjs').then(module => module.main())"
      util.javascript_run(
        deno: ["eval", script, "--unstable", "--", ..start_arguments()],
        or: ["--eval=" <> script, "--title=rad", "--", ..start_arguments()],
        opt: [LetBeStderr, LetBeStdout],
      )
      |> end_task
    }

    _else, _any ->
      snag.error("unknown target `" <> with <> "`")
      |> snag.context("failed to run task")
      |> end_task
  }
}

fn is_running(target: String) -> Bool {
  target
  |> string.lowercase
  |> do_is_running
}

@target(erlang)
fn do_is_running(target: String) -> Bool {
  case target {
    "erlang" -> True
    _else -> False
  }
}

@target(javascript)
fn do_is_running(target: String) -> Bool {
  case target {
    "javascript" -> True
    _else -> False
  }
}

fn gleam_build(target: String) -> Result(String, Snag) {
  let target = "--target=" <> target
  ["build", target]
  |> shellout.command(run: "gleam", in: ".", opt: [LetBeStderr, LetBeStdout])
  |> result.replace_error(snag.new("failed to run task"))
}

fn gleam_run(package: String, module: String) -> Nil {
  do_gleam_run(package, module)
}

@target(erlang)
fn do_gleam_run(package: String, module: String) -> Nil {
  let _result =
    package
    |> maybe_run(module)
    |> result.lazy_or(fn() {
      let result = gleam_build("erlang")
      io.println("")
      result
      |> result.try(apply: fn(_result) { maybe_run(package, module) })
    })
    |> result.map_error(with: fn(snag) {
      let _nil =
        snag
        |> util.snag_pretty_print
        |> io.println
      erlang_gleam_run(package, default_workbook)
    })
  Nil
}

@target(javascript)
@external(javascript, "./rad_ffi.mjs", "gleam_run")
fn do_gleam_run(package: String, module: String) -> Nil

@target(erlang)
@external(erlang, "rad_ffi", "maybe_run")
fn maybe_run(package: String, module: String) -> Result(String, Snag)

@target(erlang)
@external(erlang, "rad_ffi", "gleam_run")
fn erlang_gleam_run(package: String, module: String) -> dynamic.Dynamic
