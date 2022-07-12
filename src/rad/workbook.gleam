//// TODO: --with for all help
//// TODO: Theme record
//// TODO
////

import gleam/dynamic
import gleam/function
import gleam/list
import gleam/map.{Map}
import gleam/option.{None, Option, Some}
import gleam/order.{Order}
import gleam/pair
import gleam/result
import gleam/string
import glint.{CommandInput}
import glint/flag
import rad/task.{Parsed, Result, Runner, Task, Tasks}
import rad/toml
import rad/util
import shellout.{StyleFlags}
import snag

const flag_color = "purple"

const heading_color = "buttercup"

const parameter_color = "mint"

const path_color = "boi-blue"

const subcommand_color = "mint"

const tab = "    "

/// TODO
///
pub type Workbook =
  Map(List(String), Task(Result))

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Workbook Builder Functions             //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

/// TODO
///
pub fn new() -> Workbook {
  map.new()
}

/// TODO
///
pub fn from_tasks(list: Tasks) -> Workbook {
  new()
  |> tasks(add: list)
}

/// TODO
///
pub fn task(into workbook: Workbook, add task: Task(Result)) -> Workbook {
  workbook
  |> map.insert(for: task.path, insert: task)
}

/// TODO
///
pub fn tasks(into workbook: Workbook, add tasks: Tasks) -> Workbook {
  tasks
  |> list.fold(from: workbook, with: task)
}

/// TODO
///
pub fn delete(from workbook: Workbook, path: List(String)) -> Workbook {
  workbook
  |> map.delete(delete: path)
}

/// TODO
///
pub fn to_tasks(workbook: Workbook) -> Tasks {
  map.values(workbook)
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Help Functions                         //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

/// Builds help dialogues for the given [`Workbook`](#Workbook) and any of its tasks.
///
/// Any [`Task`](task.html#Task) with an empty `shortdoc` field, or for which no parent
/// [`Task`](task.html#Task) exists, is hidden from ancestor help dialogues, but can be
/// viewed directly.
///
pub fn help(from workbook_fun: fn() -> Workbook) -> Runner(Result) {
  fn(input: CommandInput, task: Task(Result)) {
    let config = task.config

    let path = case task.path {
      ["help"] -> input.args
      _else -> task.path
    }

    let workbook =
      task.tasks_from_config()
      |> result.values
      |> tasks(into: workbook_fun())

    try task =
      workbook
      |> map.get(path)
      |> result.replace_error(snag.new("rad task not found"))
    let task = Task(..task, config: config)

    // Get subtasks
    let tasks =
      workbook
      |> to_tasks
      |> list.filter_map(with: fn(task) {
        let #(compare_path, subpath) =
          task.path
          |> list.split(at: list.length(path))
        case
          path == compare_path && list.length(subpath) == 1 && task.shortdoc != ""
        {
          True ->
            Task(..task, path: subpath)
            |> Ok
          False -> Error(Nil)
        }
      })

    let has_flags = task.flags != []
    let has_parameters = task.parameters != []
    let has_tasks = tasks != []

    try info = info(task)
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
          |> map.merge(from: shellout.color([path_color])),
          custom: util.lookups,
        )
        |> Some
    }

    let subcommand = case has_tasks {
      True ->
        "<subcommand>"
        |> shellout.style(
          with: shellout.color([subcommand_color]),
          custom: util.lookups,
        )
        |> Some
      False -> None
    }

    let flags = case has_flags {
      True ->
        "[flags]"
        |> shellout.style(
          with: shellout.color([flag_color]),
          custom: util.lookups,
        )
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
          custom: util.lookups,
        )
        |> Some
      False -> None
    }

    let usage =
      "rad"
      |> shellout.style(
        with: shellout.display(["bold"])
        |> map.merge(from: shellout.color(["pink"])),
        custom: util.lookups,
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
}

/// Gathers and formats information about `rad`.
///
pub fn info(task: Task(Result)) -> Result {
  // Check if `rad` is the base project or a dependency
  assert Parsed(toml) = task.config
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
      |> map.merge(from: shellout.color(["pink"])),
      custom: util.lookups,
    )
    |> Some

  let version =
    ["version"]
    |> toml.decode(from: toml, expect: dynamic.string)
    |> result.map(with: shellout.style(
      _,
      with: shellout.display(["italic"]),
      custom: util.lookups,
    ))
    |> option.from_result

  let description =
    ["description"]
    |> toml.decode(from: toml, expect: dynamic.string)
    |> result.map(with: shellout.style(
      _,
      with: shellout.display(["italic"])
      |> map.merge(from: shellout.color(["purple"])),
      custom: util.lookups,
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
    |> map.merge(from: shellout.color([heading_color])),
    custom: util.lookups,
  )
}

/// TODO
///
pub fn section(
  named name: String,
  when cond: Bool,
  enum items: List(a),
  with format_fun: fn(a) -> #(String, String),
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
            |> shellout.style(with: style, custom: util.lookups)
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
