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
  import gleam/erlang/atom.{Atom}
}

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
      ["rad", "workbook"]
      |> toml.decode(from: config, expect: dynamic.string)
      |> result.unwrap(
        or: case with {
          "javascript" -> "../rad/"
          _else -> ""
        }
        |> string.append(suffix: default_workbook),
      )
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
    Error(snag) -> {
      snag
      |> util.snag_pretty_print
      |> io.print
      shellout.exit(1)
    }
  }
}

fn rad_run(with: String, fun: fn() -> Nil) -> Nil {
  case is_running(with), with {
    True, _any -> fun()

    _else_if, "erlang" ->
      {
        try _output = case
          util.file_exists("./build/dev/erlang/rad/ebin/rad.app")
        {
          True -> Ok("")
          False -> gleam_build("erlang")
        }
        // Run `rad` with Erlang
        [
          ["-noshell"],
          ["-eval", "gleam@@main:run(rad)"],
          ["-extra", ..shellout.arguments()],
        ]
        |> list.flatten
        |> util.erlang_run(opt: [LetBeStderr, LetBeStdout])
      }
      |> end_task

    _else_if, "javascript" ->
      [
        ["--title=rad"],
        [
          "--eval=import('./build/dev/javascript/rad/rad.mjs').then(module => module.main())",
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

fn gleam_build(target: String) -> Result(String, Snag) {
  let target =
    ["--target=", target]
    |> string.concat
  ["build", target]
  |> shellout.command(run: "gleam", in: ".", opt: [LetBeStderr, LetBeStdout])
  |> result.replace_error(snag.new("failed to run task"))
}

fn gleam_run(module: String) -> Nil {
  do_gleam_run(module)
}

if erlang {
  fn do_gleam_run(module: String) -> Nil {
    let _result =
      module
      |> maybe_run
      |> result.lazy_or(fn() {
        let result = gleam_build("erlang")
        io.println("")
        result
        |> result.then(apply: fn(_result) { maybe_run(module) })
      })
      |> result.map_error(with: fn(snag) {
        let _nil =
          snag
          |> util.snag_pretty_print
          |> io.println
        default_workbook
        |> atomize
        |> erlang_gleam_run
      })
    Nil
  }

  fn maybe_run(module: String) -> Result(String, Snag) {
    try _result =
      module
      |> ensure_loaded
    case function_exported(module, "main", 0) {
      True -> {
        let _dynamic =
          module
          |> atomize
          |> erlang_gleam_run
        Ok("")
      }
      False ->
        ["`", module, ".main` not found"]
        |> string.concat
        |> snag.error
    }
  }

  fn ensure_loaded(module: String) -> Result(String, Snag) {
    let error = atom.create_from_string("error")
    let atoms =
      module
      |> atomize
      |> code_purge
      |> code_delete
      |> do_ensure_loaded
    case atoms {
      #(result, _any) if result == error ->
        ["failed to load module `", module, "`"]
        |> string.concat
        |> snag.error
      _else -> Ok(module)
    }
  }

  fn atomize(module: String) -> Atom {
    module
    |> string.replace(each: "/", with: "@")
    |> atom.create_from_string
  }

  fn code_purge(module: Atom) -> Atom {
    let _bool = do_code_purge(module)
    module
  }

  external fn do_code_purge(Atom) -> Bool =
    "code" "purge"

  fn code_delete(module: Atom) -> Atom {
    let _bool = do_code_delete(module)
    module
  }

  external fn do_code_delete(Atom) -> Bool =
    "code" "delete"

  external fn do_ensure_loaded(Atom) -> #(Atom, Atom) =
    "code" "ensure_loaded"

  fn function_exported(module: String, fun: String, arity: Int) -> Bool {
    let module = atomize(module)
    let fun = atom.create_from_string(fun)
    do_function_exported(module, fun, arity)
  }

  external fn do_function_exported(Atom, Atom, Int) -> Bool =
    "erlang" "function_exported"

  external fn erlang_gleam_run(Atom) -> dynamic.Dynamic =
    "gleam@@main" "run"
}

if javascript {
  external fn do_gleam_run(String) -> Nil =
    "./rad_ffi.mjs" "gleam_run"
}
