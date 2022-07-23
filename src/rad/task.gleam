//// Tasks represent commands that can be invoked from the `rad` command line
//// interface.
////
//// A collection of tasks that can be handled by
//// [`rad.do_main`](../rad.html#do_main) is called a
//// [`Workbook`](workbook.html#Workbook).
////

import gleam
import gleam/dynamic
import gleam/int
import gleam/json
import gleam/list
import gleam/pair
import gleam/result
import gleam/string
import glint.{CommandInput}
import glint/flag.{Flag}
import rad/toml.{Toml}
import rad/util
import shellout
import snag.{Snag}

/// The basic configuration unit for the `rad` command line interface.
///
/// A `Task` can be conveniently built up using the following functions:
/// [`new`](#new), followed by any number of [`shortdoc`](#shortdoc),
/// [`flag`](#flag), [`flags`](#flags), [`parameter`](#parameter),
/// [`parameters`](#parameters), [`with_config`](#with_config), and
/// [`for`](#for) combined with [`arguments`](#arguments),
/// [`targets`](#targets), or a custom [`Iterable`](#Iterable)-generating
/// function.
///
/// Any number of tasks can be added to a [`new`](workbook.html#new) or existing
/// [`Workbook`](workbook.html#Workbook), such as the standard
/// [`workbook`](workbook/standard.html#workbook), to compose a custom
/// [`Workbook`](workbook.html#Workbook) that can be given to
/// [`rad.do_main`](../rad.html#do_main).
///
pub type Task(a) {
  Task(
    path: List(String),
    run: Runner(a),
    for: Iterable(a),
    delimiter: String,
    shortdoc: String,
    flags: List(Flag),
    parameters: List(#(String, String)),
    config: Config,
  )
}

/// A function that takes
/// [`CommandInput`](https://hexdocs.pm/glint/glint.html#CommandInput) and a
/// given [`Task`](#Task) and does any number of things with them.
///
pub type Runner(a) =
  fn(CommandInput, Task(a)) -> a

/// A value for the `for` field of every [`Task`](#Task).
///
/// An `Iterable` tells a [`Runner`](#Runner) which items to iterate over and
/// how input should be mapped at the beginning of each iteration.
///
/// A [`new`](#new) [`Task`](#Task) defined in a
/// [`Workbook`](workbook.html#Workbook), will ask its [`Runner`](#Runner) to
/// iterate `Once`. This can be changed using the [`for`](#for) builder
/// function.
///
/// At runtime, when a [`Runner`](#Runner) sees that its [`Task`](#Task) needs
/// to run for `Each` of any number of items, it can proceed accordingly. A
/// [`trainer`](#trainer) does this for its [`Runner`](#Runner) automatically.
///
pub type Iterable(a) {
  Each(
    get: fn(CommandInput, Task(a)) -> List(String),
    map: fn(CommandInput, Task(a), Int, List(String)) -> CommandInput,
  )
  Once
}

/// A value for the `config` field of every [`Task`](#Task).
///
/// A [`new`](#new) [`Task`](#Task) defined in a
/// [`Workbook`](workbook.html#Workbook), won't ask its [`Runner`](#Runner) to
/// access the `gleam.toml` configuration file (`NoConfig`). This can be changed
/// using the [`with_config`](#with_config) builder function (`Config`).
///
/// At runtime, when a [`Runner`](#Runner) sees that its [`Task`](#Task) needs
/// the [`Toml`](toml.html#Toml) data, it can fetch it once and use it as needed
/// (`Parsed`). A [`trainer`](#trainer) does this for its [`Runner`](#Runner)
/// automatically.
///
pub type Config {
  Config
  NoConfig
  Parsed(Toml)
}

/// The standard return type for a [`Task`](#Task).
///
/// Contains a string of output on success, or a
/// [`Snag`](https://hexdocs.pm/snag/snag.html#Snag) on failure.
///
pub type Result =
  gleam.Result(String, Snag)

/// A list in which each item is a [`Task`](#Task) that returns a
/// [`Result`](#Result).
///
pub type Tasks =
  List(Task(Result))

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Task Builder Functions                 //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

/// Returns a new [`Task`](#Task) with the given `path` and `runner`, which is
/// assisted by a [`trainer`](#trainer) to reduce boilerplate code for common
/// scenarios.
///
/// The `path` is a list of words that, when given in sequence using `rad`'s
/// command line interface, invoke the [`Task`](#Task), which will then be
/// processed together with any other input arguments and run by the `runner`.
/// For example, if `rad` is invoked from the command line with
/// `rad hearts gleam`, it will try to run a [`Task`](#Task) with the `path`:
/// `["hearts", "gleam"]`.
///
pub fn new(at path: List(String), run runner: Runner(Result)) -> Task(Result) {
  Task(
    path: path,
    run: trainer(runner),
    for: Once,
    delimiter: "\n",
    shortdoc: "",
    flags: [],
    parameters: [],
    config: NoConfig,
  )
}

/// Returns a new [`Task`](#Task) with the given delimiter string.
///
/// This string is printed between items when a task runs [`for`](#for) multiple
/// iterations.
///
pub fn delimit(iterable task: Task(a), with delimiter: String) -> Task(a) {
  Task(..task, delimiter: delimiter)
}

/// Returns a new [`Task`](#Task) with the given input
/// [`Flag`](https://hexdocs.pm/glint/glint/flag.html#Flag) appended.
///
/// A [`Flag`](https://hexdocs.pm/glint/glint/flag.html#Flag) defines an
/// optional argument that its [`Task`](#Task) accepts from command line input.
///
pub fn flag(
  into task: Task(a),
  called name: String,
  explained description: String,
  expect flag_fun: fn(String, b, String) -> Flag,
  default value: b,
) -> Task(a) {
  let flag =
    name
    |> flag_fun(value, description)
  let flags =
    task.flags
    |> list.append([flag])
  Task(..task, flags: flags)
}

/// Returns a new [`Task`](#Task) with the given list of input flags appended.
///
/// A [`Flag`](https://hexdocs.pm/glint/glint/flag.html#Flag) defines an
/// optional argument that its [`Task`](#Task) accepts from command line input.
///
pub fn flags(into task: Task(a), add flags: List(Flag)) -> Task(a) {
  let flags =
    task.flags
    |> list.append(flags)
  Task(..task, flags: flags)
}

/// Returns a new [`Task`](#Task) with the given `iter_fun`, a function that
/// returns an [`Iterable`](#Iterable) telling the [`Runner`](#Runner) which
/// items to iterate over and how input should be mapped at the beginning of
/// each iteration.
///
pub fn for(do task: Task(a), each iter_fun: fn() -> Iterable(a)) -> Task(a) {
  Task(..task, for: iter_fun())
}

/// Returns a new [`Task`](#Task) with the given parameter documentation
/// appended.
///
/// Parameter docs are used by the [`help`](workbook.html#help) function to
/// describe what extra arguments do for a given [`Task`](#Task).
///
pub fn parameter(
  into task: Task(a),
  with usage: String,
  of description: String,
) -> Task(a) {
  let parameters =
    task.parameters
    |> list.append([#(usage, description)])
  Task(..task, parameters: parameters)
}

/// Returns a new [`Task`](#Task) with the given list of parameter documentation
/// pairs appended.
///
/// Parameter docs are used by the [`help`](workbook.html#help) function to
/// describe what extra arguments do for a given [`Task`](#Task).
///
pub fn parameters(
  into task: Task(a),
  add parameters: List(#(String, String)),
) -> Task(a) {
  let parameters =
    task.parameters
    |> list.append(parameters)
  Task(..task, parameters: parameters)
}

/// Returns a new [`Task`](#Task) with the given short documentation string.
///
pub fn shortdoc(into task: Task(a), insert description: String) -> Task(a) {
  Task(..task, shortdoc: description)
}

/// Returns a new [`Task`](#Task) that wants the `gleam.toml` configuration
/// file's [`Parsed`](#Config) [`Toml`](toml.html#Toml) data, to be used by the
/// [`Task`](#Task)'s [`Runner`](#Runner).
///
/// Note that a [`Runner`](#Runner) will need to handle this requirement at
/// runtime in order to succeed. A [`trainer`](#trainer) does this for its
/// [`Runner`](#Runner) automatically.
///
pub fn with_config(task: Task(a)) -> Task(a) {
  Task(..task, config: Config)
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Iterable Functions                     //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

/// Returns a function that generates a given [`Iterable`](#Iterable) when the
/// [`Runner`](#Runner)'s
/// [`CommandInput`](https://hexdocs.pm/glint/glint.html#CommandInput) contains
/// a boolean input [`Flag`](https://hexdocs.pm/glint/glint/flag.html#Flag)
/// called `flag_name` with a `True` value, or another [`Iterable`](#Iterable)
/// otherwise.
///
/// An [`Iterable`](#Iterable) can be attached to a given [`Task`](#Task) using
/// the [`for`](#for) builder function.
///
pub fn or(
  true_fun: fn() -> Iterable(a),
  cond flag_name: String,
  else false_fun: fn() -> Iterable(a),
) -> fn() -> Iterable(a) {
  let cond = fn(input: CommandInput) {
    assert Ok(flag.B(flag_value)) =
      flag_name
      |> flag.get_value(from: input.flags)
    case flag_value {
      True -> true_fun()
      False -> false_fun()
    }
  }

  let items_fun = fn(input: CommandInput, task) {
    case cond(input) {
      Each(get: items_fun, ..) -> items_fun(input, task)
      _else -> [util.encode_json(input.args)]
    }
  }

  let mapper = fn(input: CommandInput, task, index, item) {
    case cond(input) {
      Each(map: mapper, ..) -> mapper(input, task, index, item)
      _else -> {
        let [item] = item
        item
        |> json.decode(using: dynamic.list(of: dynamic.string))
        |> result.unwrap(or: [])
        |> CommandInput(flags: input.flags)
      }
    }
  }

  fn() { Each(get: items_fun, map: mapper) }
}

/// Returns an [`Iterable`](#Iterable) that tells a [`Runner`](#Runner) how to
/// run for each of a list of input arguments.
///
/// An [`Iterable`](#Iterable) can be attached to a given [`Task`](#Task) using
/// the [`for`](#for) builder function.
///
pub fn arguments() -> Iterable(a) {
  let items_fun = fn(input: CommandInput, _task) { input.args }

  let mapper = fn(input, _task, _index, argument) {
    CommandInput(..input, args: argument)
  }

  Each(get: items_fun, map: mapper)
}

/// A type that describes an external source code formatter.
///
/// If a [`Task`](#Task) uses [`formatters`](#formatters) as its
/// [`Iterable`](#Iterable), that task will run the `gleam` formatter along with
/// any formatters defined in your `gleam.toml` config via the `rad.formatters`
/// table array.
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
pub type Formatter {
  Formatter(name: String, check: List(String), run: List(String))
}

/// Returns an [`Iterable`](#Iterable) that tells a [`Runner`](#Runner) how to
/// run for each project [`Formatter`](#Formatter). The Gleam
/// [`Formatter`](#Formatter) is always included.
///
/// An [`Iterable`](#Iterable) can be attached to a given [`Task`](#Task) using
/// the [`for`](#for) builder function.
///
pub fn formatters() -> Iterable(a) {
  let formatters = [
    "gleam"
    |> Formatter(
      check: ["gleam", "format", "--check"],
      run: ["gleam", "format"],
    )
    |> Ok,
    ..formatters_from_config()
  ]

  let items_fun = fn(_input, _task) {
    formatters
    |> list.map(with: fn(_result) { "" })
  }

  let mapper = fn(input: CommandInput, _task, index, _argument) {
    let io_println = util.quiet_or_println(input)
    assert Ok(flag.B(check)) =
      "check"
      |> flag.get_value(from: input.flags)
    let result =
      formatters
      |> list.at(get: index)
      |> result.unwrap(or: snag.error(""))

    case result {
      Ok(formatter) -> {
        let #(action, extra, args) = case check {
          True -> #("   Checking", " formatting", formatter.check)
          False -> #(" Formatting", "", formatter.run)
        }
        let _print =
          [
            action
            |> shellout.style(with: shellout.color(["magenta"]), custom: []),
            " ",
            formatter.name,
            extra,
            "...\n",
          ]
          |> string.concat
          |> io_println
        args
        |> CommandInput(flags: input.flags)
      }
      _else ->
        "--fail"
        |> flag.update_flags(in: input.flags)
        |> result.unwrap(or: input.flags)
        |> CommandInput(args: [])
    }
  }

  Each(get: items_fun, map: mapper)
}

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

/// Returns an [`Iterable`](#Iterable) that tells a [`Runner`](#Runner) how to
/// run for each project dependency and the project itself.
///
/// An [`Iterable`](#Iterable) can be attached to a given [`Task`](#Task) using
/// the [`for`](#for) builder function.
///
pub fn packages() -> Iterable(a) {
  let items_fun = fn(_input, task: Task(a)) {
    assert Parsed(toml) = task.config
    assert Ok(self) =
      ["name"]
      |> toml.decode(from: toml, expect: dynamic.string)
    let dependencies =
      ["dependencies"]
      |> toml.decode_every(from: toml, expect: dynamic.string)
      |> result.unwrap(or: [])
    let dev_dependencies =
      ["dev-dependencies"]
      |> toml.decode_every(from: toml, expect: dynamic.string)
      |> result.unwrap(or: [])
    [
      self,
      ..[dependencies, dev_dependencies]
      |> list.flatten
      |> list.map(with: pair.first)
      |> list.sort(by: string.compare)
    ]
    |> list.unique
  }

  let mapper = fn(input: CommandInput, _task, _index, argument) {
    CommandInput(..input, args: argument)
  }

  Each(get: items_fun, map: mapper)
}

/// Returns an [`Iterable`](#Iterable) that tells a [`Runner`](#Runner) how to
/// run for each compilation target.
///
/// An [`Iterable`](#Iterable) can be attached to a given [`Task`](#Task) using
/// the [`for`](#for) builder function.
///
pub fn targets() -> Iterable(a) {
  let items_fun = fn(input: CommandInput, _task) {
    assert Ok(flag.LS(targets)) =
      "target"
      |> flag.get_value(from: input.flags)
    targets
    |> list.unique
  }

  let mapper = fn(input: CommandInput, _task, _index, target) {
    let io_println = util.quiet_or_println(input)
    let target = case target {
      [target] -> target
      _else -> ""
    }
    let _heading =
      [
        "  Targeting"
        |> shellout.style(with: shellout.color(["magenta"]), custom: []),
        " ",
        target,
        "...",
      ]
      |> string.concat
      |> io_println
    assert Ok(flags) =
      ["--target=", target]
      |> string.concat
      |> flag.update_flags(in: input.flags)
    CommandInput(..input, flags: flags)
  }

  Each(get: items_fun, map: mapper)
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Task Runner Functions                  //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

/// Returns a basic [`Runner`](#Runner) that runs its [`Task`](#Task) using the
/// given `command`.
///
/// Basic runners are used for tasks defined in `gleam.toml`.
///
pub fn basic(command: List(String)) -> Runner(Result) {
  fn(input: CommandInput, _task) {
    let [command, ..args] = command
    [args, util.relay_flags(input.flags), input.args]
    |> list.flatten
    |> shellout.command(run: command, in: ".", opt: util.quiet_or_spawn(input))
    |> result.replace_error(snag.new("failed running task"))
  }
}

/// Returns a [`Runner`](#Runner) that runs the `gleam` build tool with the
/// given `arguments`.
///
/// Gleam runners can be used for tasks defined in a
/// [`Workbook`](workbook.html#Workbook).
///
pub fn gleam(arguments: List(String)) -> Runner(Result) {
  fn(input: CommandInput, _task) {
    [arguments, util.relay_flags(input.flags), input.args]
    |> list.flatten
    |> shellout.command(run: "gleam", in: ".", opt: util.quiet_or_spawn(input))
    |> result.replace("")
    |> result.replace_error(snag.new("failed running task"))
  }
}

/// Returns a [`Runner`](#Runner) that works with a given `runner` to run its
/// [`Task`](#Task) one or more times.
///
/// If the [`Task`](#Task) contains an [`Iterable`](#Iterable), all runs are
/// attempted regardless of any failures along the way; however, the end
/// [`Result`](#Result) will only be successful if no errors are produced.
///
/// Trainer runners are used for tasks defined in a
/// [`Workbook`](workbook.html#Workbook).
///
pub fn trainer(runner: Runner(Result)) -> Runner(Result) {
  fn(input, task: Task(Result)) {
    let io_print = util.quiet_or_print(input)
    let config = case task.config {
      Config ->
        "gleam.toml"
        |> toml.parse_file
        |> result.lazy_unwrap(or: toml.new)
        |> Parsed
      _else -> task.config
    }
    let task = Task(..task, config: config)

    let #(items, mapper) = case task.for {
      Each(get: items_fun, map: mapper) -> #(items_fun(input, task), mapper)
      Once -> #([], fn(input, _task, _index, _target) { input })
    }
    let last_index = list.length(items) - 1
    let is_aggregate = last_index > 0

    let #(oks, errors) =
      case items {
        [] -> {
          let result =
            input
            |> mapper(task, 0, input.args)
            |> runner(task)
          [result]
        }
        _else ->
          items
          |> list.index_map(with: fn(index, item) {
            let end_aggregate_run = fn(output) {
              let output = case string.ends_with(output, "\n") {
                True ->
                  output
                  |> string.drop_right(up_to: 1)
                False -> output
              }
              let end = case index == last_index {
                True if output == "" -> ""
                True -> "\n"
                False -> task.delimiter
              }
              [output, end]
              |> string.concat
              |> io_print
            }
            let result =
              input
              |> mapper(task, index, [item])
              |> runner(task)
            case is_aggregate, result {
              True, Ok(output) -> {
                let _print =
                  output
                  |> end_aggregate_run
                Ok("")
              }
              True, Error(snag) -> {
                let _print =
                  snag
                  |> util.snag_pretty_print
                  |> end_aggregate_run
                result
              }
              _else, _any -> result
            }
          })
      }
      |> list.partition(with: result.is_ok)

    // Combine results
    case oks, errors {
      [], [error] -> error
      _any, [] ->
        oks
        |> result.values
        |> list.filter(for: fn(output) { output != "" })
        |> string.join(with: task.delimiter)
        |> Ok
      _else, _any -> {
        io_print("\n")
        let errors = list.length(of: errors)
        let results =
          [errors, list.length(of: oks)]
          |> int.sum
          |> int.to_string
        [
          errors
          |> int.to_string,
          "of",
          results,
          "task runs failed",
        ]
        |> string.join(with: " ")
        |> snag.error
      }
    }
    |> result.map(with: string.trim)
  }
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Miscellaneous Functions                //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

/// Sort [`Tasks`](#Tasks) alphabetically by `path`.
///
pub fn sort(tasks: Tasks) -> Tasks {
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

/// Parses `gleam.toml` for tasks defined in the `[[rad.tasks]]` table array.
///
/// A defined [`Task`](#Task) must have `path` and `run` key/values, and may
/// optionally have a `shortdoc` key/value.
///
pub fn tasks_from_config() -> List(gleam.Result(Task(Result), Snag)) {
  let dynamic_strings = fn(name) {
    dynamic.field(named: name, of: dynamic.list(of: dynamic.string))
  }
  let requirements =
    fn(path, command) {
      path
      |> new(run: basic(command))
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
    task
    |> shortdoc(
      ["shortdoc"]
      |> toml.decode(from: toml, expect: dynamic.string)
      |> result.unwrap(or: ""),
    )
    |> Ok
  })
}
