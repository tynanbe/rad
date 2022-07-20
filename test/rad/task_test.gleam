import gleam/dynamic
import gleam/function
import gleam/int
import gleam/list
import gleam/map
import gleam/result
import gleam/string
import gleeunit/should
import glint.{CommandInput}
import glint/flag
import rad/task.{Config, Each, NoConfig, Once, Parsed, Result, Task}
import rad/toml
import rad/util
import rad/workbook
import rad/workbook/standard
import rad_test.{empty_input, input, run, task}
import snag

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Task Builder Functions                 //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

pub fn builder_test() {
  let path = ["d", "e", "f"]

  // Create
  let builder =
    path
    |> task.new(run: task.basic(["echo"]))

  builder.path
  |> should.equal(path)

  ["a", "b", "c"]
  |> input(flags: [])
  |> run(builder)
  |> should.be_ok

  builder.for
  |> should.equal(Once)

  builder.shortdoc
  |> should.equal("")

  builder.flags
  |> should.equal([])

  builder.parameters
  |> should.equal([])

  builder.config
  |> should.equal(NoConfig)

  // Update
  let shortdoc = "Lucy, I'm home!"
  let #(_name, flag1_contents) as flag1 =
    "all"
    |> flag.bool(default: False, explained: "For one")
  let flags = [
    flag.string(called: "one", default: "for", explained: "All"),
    flag.strings(called: "target", default: ["erlang"], explained: ""),
  ]
  let #(_name, flag4_contents) as flag4 =
    "zero"
    |> flag.int(default: 0, explained: "")
  let parameter1 = #("[g]", "")
  let parameters = [#("[h]", ""), #("[i]", "Some j")]
  let parameter4 = #("[k]", "None")
  let builder =
    builder
    |> task.for(each: task.arguments)
    |> task.shortdoc(insert: shortdoc)
    |> task.flag(
      called: flag1.0,
      explained: flag1_contents.description,
      expect: flag.bool,
      default: False,
    )
    |> task.flags(add: flags)
    |> task.flag(
      called: flag4.0,
      explained: flag4_contents.description,
      expect: flag.int,
      default: 0,
    )
    |> task.parameter(with: parameter1.0, of: parameter1.1)
    |> task.parameters(add: parameters)
    |> task.parameter(with: parameter4.0, of: parameter4.1)
    |> task.with_config

  builder.path
  |> should.equal(path)

  ["a", "b", "c"]
  |> input(flags: [])
  |> run(builder)
  |> should.be_ok

  builder.for
  |> should.not_equal(Once)

  builder.shortdoc
  |> should.equal(shortdoc)

  [[flag1], flags, [flag4]]
  |> list.flatten
  |> should.equal(builder.flags)

  [[parameter1], parameters, [parameter4]]
  |> list.flatten
  |> should.equal(builder.parameters)

  builder.config
  |> should.equal(Config)
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Iterable Functions                     //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

pub fn iterable_test() {
  let flags = [
    "target"
    |> flag.strings(default: ["erlang"], explained: "Nock on, Hood"),
    "rad-test"
    |> flag.bool(default: True, explained: ""),
  ]
  assert Ok(input_flags) =
    flags
    |> map.from_list
    |> flag.update_flags(with: "--target=erlang,javascript")
  let input =
    ["a", "b", "c"]
    |> CommandInput(flags: input_flags)

  // task.arguments
  let builder =
    []
    |> task.new(run: task.basic(["echo"]))
    |> task.for(each: task.arguments)
    |> task.flags(add: flags)
  assert Each(get: items_fun, map: mapper) = builder.for
  let _items =
    input
    |> items_fun(builder)
    |> should.equal(input.args)
  let item =
    input
    |> mapper(builder, 0, ["a"])
  item.args
  |> should.equal(["a"])

  // task.targets
  let builder =
    builder
    |> task.for(each: task.targets)
  assert Ok(flag.LS(targets)) =
    "target"
    |> flag.get_value(from: input.flags)
  assert Each(get: items_fun, map: mapper) = builder.for
  let _items =
    input
    |> items_fun(builder)
    |> should.equal(targets)
  let item =
    input
    |> mapper(builder, 0, ["erlang"])
  assert Ok(flag.LS(target)) =
    "target"
    |> flag.get_value(from: item.flags)
  target
  |> should.equal(["erlang"])
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Task Runner Functions                  //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

pub fn config_test() {
  let runner = fn(_input, task: Task(Result)) {
    case task.config {
      Parsed(toml) ->
        []
        |> toml.decode(from: toml, expect: dynamic.dynamic)
        |> result.map(with: util.encode_json)
      _else -> Error(snag.new(""))
    }
  }

  let builder =
    []
    |> task.new(run: runner)
    |> task.with_config
  empty_input()
  |> run(builder)
  |> should.be_ok

  let builder =
    []
    |> task.new(run: runner)
  empty_input()
  |> run(builder)
  |> should.be_error
}

pub fn basic_test() {
  let builder =
    []
    |> task.new(run: task.basic(["echo"]))
  empty_input()
  |> run(builder)
  |> should.be_ok

  let builder =
    []
    |> task.new(run: task.basic([""]))
  empty_input()
  |> run(builder)
  |> should.be_error
}

pub fn gleam_test() {
  let builder =
    []
    |> task.new(run: task.gleam([]))

  ["--", "--version"]
  |> input(flags: [])
  |> run(builder)
  |> should.be_ok

  ["help", "haaalp"]
  |> input(flags: [])
  |> run(builder)
  |> should.be_error
}

pub fn trainer_test() {
  let builder =
    []
    |> task.new(run: fn(input, _task) {
      input.args
      |> list.map(with: fn(arg) {
        let not_oddish =
          ["not", arg]
          |> string.join(with: " ")
          |> snag.new
          |> function.constant
        try maybe_oddish =
          arg
          |> int.parse
          |> result.map_error(with: not_oddish)
        case int.is_odd(maybe_oddish) {
          True ->
            ["oddish", arg]
            |> string.join(with: " ")
            |> Ok
          False ->
            Nil
            |> not_oddish
            |> Error
        }
      })
      |> result.all
      |> result.map(with: string.join(_, with: ", "))
    })

  ["1"]
  |> input(flags: [])
  |> run(builder)
  |> should.equal(Ok("oddish 1"))

  ["1", "2"]
  |> input(flags: [])
  |> run(builder)
  |> should.be_error

  let args = ["1", "3", "5"]

  args
  |> input(flags: [])
  |> run(builder)
  |> should.equal(
    args
    |> list.map(with: string.append(to: "oddish ", suffix: _))
    |> string.join(with: ", ")
    |> Ok,
  )

  let builder =
    builder
    |> task.for(each: task.arguments)

  args
  |> input(flags: [])
  |> run(builder)
  |> should.equal(Ok(""))

  ["1", "2", "3"]
  |> input(flags: [])
  |> run(builder)
  |> should.be_error

  let builder =
    []
    |> task.new(run: fn(input, task) {
      assert Parsed(toml) = task.config
      input.args
      |> toml.decode(from: toml, expect: dynamic.string)
    })
    |> task.with_config

  ["name"]
  |> input(flags: [])
  |> run(builder)
  |> should.equal(Ok("rad"))
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Miscellaneous Functions                //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

// TODO: uncomment for gleam_stdlib > 0.22.1
//pub fn tasks_from_config_test() {
//  let tasks =
//    task.tasks_from_config()
//    |> result.values
//
//  tasks
//  |> list.find(one_that: fn(task) {
//    case task.path {
//      [_at_least, _two, ..] -> True
//      _else -> False
//    }
//  })
//  |> should.be_ok
//
//  tasks
//  |> list.find(one_that: fn(task) { task.shortdoc != "" })
//  |> should.be_ok
//
//  tasks
//  |> list.map(with: fn(builder) {
//    empty_input()
//    |> run(builder)
//  })
//  |> result.all
//  |> should.be_ok
//}

pub fn sort_test() {
  let [head, ..rest] =
    standard.workbook()
    |> workbook.to_tasks
    |> list.sized_chunk(into: 3)
    |> list.reverse
    |> list.flatten
    |> task.sort

  head.path
  |> should.equal([])

  let #(_discard, [_watch, watch_do, ..]) =
    rest
    |> list.split_while(satisfying: fn(task) { task.path != ["watch"] })
  watch_do.path
  |> should.equal(["watch", "do"])
}
