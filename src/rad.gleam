import gleam/bool
import gleam/dynamic
import gleam/function
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glint.{Help, Out}
import glint/flag
import rad/task.{Tasks}
import rad/toml
import rad/util
import shellout.{LetBeStderr, LetBeStdout}
import snag.{Snag}

if erlang {
  import gleam/dynamic.{Dynamic}
  import gleam/erlang/atom.{Atom}
}

/// Runs `rad`, a flexible task runner companion for the `gleam` build manager.
///
/// Specify a different `module` in the `[rad]` table of your `gleam.toml`
/// config to have `rad` run your module's `main` function, in which you can
/// call [`rad.do_main`](#do_main) to extend `rad` with your own tasks.
///
pub fn main() -> Nil {
  let toml =
    "gleam.toml"
    |> toml.parse_file
    |> result.lazy_unwrap(or: toml.new)
  let module =
    ["rad", "module"]
    |> toml.decode(from: toml, expect: dynamic.string)
    |> result.unwrap(or: "rad")
  let with =
    ["rad", "with"]
    |> toml.decode(from: toml, expect: dynamic.string)
    |> result.unwrap(or: "javascript")
  // Try to run any task `with` a given runtime
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
    |> glint.execute(arguments(True))
  rad_run(
    with,
    fn() {
      case module {
        "rad" -> do_main(task.tasks())
        _else -> gleam_run(module)
      }
    },
  )
}

/// Applies arguments from the command line to the given
/// [`Tasks`](rad/task.html#Tasks), then processes the output and exits.
///
/// You can merge `rad`'s [`task.Tasks`](rad/task.html#Tasks) with your own, or
/// replace them entirely.
///
/// See [`main`](#main) for more info.
///
pub fn do_main(tasks: Tasks) -> Nil {
  [
    tasks,
    task.tasks_from_config()
    |> list.map(with: result.map_error(_, with: fn(snag) {
      Snag(..snag, issue: "invalid `[[rad.tasks]]` in `gleam.toml`")
      |> snag.pretty_print
      |> string.trim
      |> string.append(suffix: "\n")
      |> io.println
    }))
    |> result.values,
  ]
  |> list.flatten
  |> list.fold(
    from: glint.new(),
    with: fn(acc, task) {
      acc
      |> glint.add_command(
        at: task.path,
        do: task.run,
        with: task.flags,
        described: task.shortdoc,
        used: ["rad", ..task.path]
        |> string.join(with: " ")
        |> string.append(suffix: " <SUBCOMMAND> <FLAGS>"),
      )
    },
  )
  |> glint.execute(arguments(False))
  |> result.map(with: fn(output) {
    case output {
      Out(result) -> result
      Help(string) -> Ok(string)
    }
  })
  |> result.flatten
  |> end_task
}

fn arguments(init: Bool) -> List(String) {
  let filter = string.starts_with(_, "--with=")
  shellout.arguments()
  |> list.filter(for: case init {
    True -> filter
    False ->
      filter
      |> function.compose(bool.negate)
  })
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
      |> snag.pretty_print
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
        try _output = case util.is_file("./build/dev/erlang/rad/ebin/rad.app") {
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
