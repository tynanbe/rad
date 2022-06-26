import gleam/bool
import gleam/function
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glint.{Help, Out}
import glint/flag
import rad/task.{Tasks}
import rad/util
import shellout.{LetBeStderr, LetBeStdout}
import snag.{Snag}

if erlang {
  import gleam/dynamic.{Dynamic}
  import gleam/erlang/atom.{Atom}
}

/// TODO
///
pub fn main() -> Nil {
  case util.is_file("gleam.toml") {
    True -> {
      let module = case util.toml(read: "gleam.toml", get: ["rad", "module"]) {
        Ok(module) -> module
        _ -> "rad"
      }
      let with = case util.toml(read: "gleam.toml", get: ["rad", "with"]) {
        Ok(with) -> with
        _ -> "javascript"
      }
      assert Ok(Out(with)) =
        glint.new()
        |> glint.add_command(
          at: [],
          do: fn(input) {
            assert Ok(flag.S(with)) =
              flag.get_value(from: input.flags, for: "with")
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
            _ -> gleam_run(module)
          }
        },
      )
    }

    False -> {
      snag.new(
        "`gleam.toml` not found; `rad` must be invoked from a Gleam project's base directory",
      )
      |> snag.pretty_print
      |> io.print
      shellout.exit(1)
    }
  }
}

/// TODO
///
pub fn do_main(tasks: Tasks) -> Nil {
  tasks
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
    False -> function.compose(filter, bool.negate)
  })
}

fn end_task(result: Result(String, Snag)) -> Nil {
  case result {
    Ok(output) -> {
      case output == "" || string.ends_with(output, "\n") {
        True -> output
        False -> string.concat([output, "\n"])
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
      _ -> False
    }
  }
}

if javascript {
  fn do_is_running(target: String) -> Bool {
    case target {
      "javascript" -> True
      _ -> False
    }
  }
}

fn rad_run(with: String, fun: fn() -> Nil) -> Nil {
  case is_running(with), with {
    True, _ -> fun()

    _, "erlang" ->
      case util.is_file("./build/dev/erlang/rad/ebin/rad.app") {
        False ->
          shellout.command(
            run: "gleam",
            with: ["build", "--target=erlang"],
            in: ".",
            opt: [LetBeStderr, LetBeStdout],
          )
          |> result.replace_error(snag.new("failed to run task"))
        True -> Ok("")
      }
      |> result.then(apply: fn(_) {
        [
          ["-noshell"],
          ["-eval", "gleam@@main:run(rad)"],
          ["-extra", ..shellout.arguments()],
        ]
        |> list.flatten
        |> util.erlang_run(opt: [LetBeStderr, LetBeStdout])
      })
      |> end_task

    _, "javascript" ->
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

    _, _ ->
      ["unknown target `", with, "`"]
      |> string.concat
      |> snag.error
      |> snag.context("failed to run task")
      |> end_task
  }
}
