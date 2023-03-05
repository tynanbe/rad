import gleam/list
import gleam/map
import gleam/result
import gleam/string
import gleeunit
import glint.{CommandInput}
import glint/flag.{Flag}
import rad/task.{Result, Task}
import rad/workbook.{Workbook}

pub fn main() {
  gleeunit.main()
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Test Helper Functions                  //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

pub fn run(input: CommandInput, task: Task(Result)) -> Result {
  input
  |> task.run(task)
}

pub fn empty_input() -> CommandInput {
  input(args: [], flags: [])
}

type ArgAcc {
  ArgAcc(flags: List(String), args: List(String), maybe_flag: Bool)
}

pub fn input(args args: List(String), flags flags: List(Flag)) -> CommandInput {
  let flags =
    [flag.bool(called: "rad-test", default: True, explained: ""), ..flags]
    |> flag.build_map

  let ArgAcc(flags: new_flags, args: args, ..) =
    args
    |> list.fold(
      from: ArgAcc(flags: [], args: [], maybe_flag: True),
      with: fn(acc, arg) {
        case arg, acc.maybe_flag, string.starts_with(arg, flag.prefix) {
          "--", True, _ -> ArgAcc(..acc, maybe_flag: False)
          _else_if, True, True ->
            ArgAcc(
              ..acc,
              flags: acc.flags
              |> list.append([arg]),
            )
          _else, _, _ ->
            ArgAcc(
              ..acc,
              args: acc.args
              |> list.append([arg]),
            )
        }
      },
    )

  new_flags
  |> list.fold(
    from: flags,
    with: fn(acc, flag) {
      acc
      |> flag.update_flags(with: flag)
      |> result.unwrap(or: acc)
    },
  )
  |> CommandInput(args: args)
}

pub fn task(from workbook: Workbook, at path: List(String)) -> Task(Result) {
  let assert Ok(task) =
    workbook
    |> map.get(path)
  task
}
