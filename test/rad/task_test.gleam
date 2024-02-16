import gleam/dict
import gleam/dynamic
import gleam/function
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import glint.{type CommandInput, CommandInput}
import glint/flag
import rad/task.{
  type Result, type Task, Each, Expected, None, Once, Parsed, Task,
}
import rad/toml
import rad/util
import rad/workbook
import rad/workbook/standard
import rad_test
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
  |> rad_test.input(flags: [])
  |> rad_test.run(builder)
  |> should.be_ok

  builder.for
  |> should.equal(Once)

  builder.delimiter
  |> should.equal("\n")

  builder.shortdoc
  |> should.equal("")

  builder.flags
  |> should.equal([])

  builder.parameters
  |> should.equal([])

  builder.config
  |> should.equal(None)

  builder.manifest
  |> should.equal(None)

  // Update
  let path = []
  let delimiter = ","
  let shortdoc = "Lucy, I'm home!"
  let #(_name, flag1_contents) as flag1 = #(
    "all",
    flag.bool()
      |> flag.default(of: False)
      |> flag.description(of: "For one")
      |> flag.build,
  )
  let flags = [
    #(
      "one",
      flag.string()
        |> flag.default(of: "for")
        |> flag.description(of: "All")
        |> flag.build,
    ),
    #(
      "target",
      flag.string_list()
        |> flag.default(of: ["erlang"])
        |> flag.build,
    ),
  ]
  let #(_name, flag4_contents) as flag4 = #(
    "zero",
    flag.int()
      |> flag.default(of: 0)
      |> flag.build,
  )
  let parameter1 = #("[g]", "")
  let parameters = [#("[h]", ""), #("[i]", "Some j")]
  let parameter4 = #("[k]", "None")
  let builder =
    builder
    |> task.path(insert: path)
    |> task.for(each: task.arguments)
    |> task.delimit(with: delimiter)
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
    |> task.with_manifest

  ["a", "b", "c"]
  |> rad_test.input(flags: [])
  |> rad_test.run(builder)
  |> should.be_ok

  let builder =
    builder
    |> task.runner(task.basic([""]))

  []
  |> rad_test.input(flags: [])
  |> rad_test.run(builder)
  |> should.be_error

  builder.path
  |> should.equal(path)

  builder.for
  |> should.not_equal(Once)

  builder.delimiter
  |> should.equal(delimiter)

  builder.shortdoc
  |> should.equal(shortdoc)

  [[flag1], flags, [flag4]]
  |> list.concat
  |> string.inspect
  |> should.equal(string.inspect(builder.flags))

  [[parameter1], parameters, [parameter4]]
  |> list.concat
  |> should.equal(builder.parameters)

  builder.config
  |> should.equal(Expected)

  builder.manifest
  |> should.equal(Expected)
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Iterable Functions                     //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

pub fn arguments_test() {
  let input = iterable_input()
  let builder =
    iterable_builder()
    |> task.for(each: task.arguments)

  let assert Each(get: items_fun, map: mapper) = builder.for

  input
  |> items_fun(builder)
  |> should.equal(input.args)

  let item = mapper(input, builder, 0, ["a"])

  item.args
  |> should.equal(["a"])
}

pub fn formatters_test() {
  let input = iterable_input()
  let builder =
    iterable_builder()
    |> task.for(each: task.formatters)

  let assert Each(get: items_fun, map: mapper) = builder.for

  case items_fun(input, builder) {
    [_gleam, _javascript, ..] -> True
    _else -> False
  }
  |> should.be_true

  let item = mapper(input, builder, 0, ["0"])

  case item.args {
    ["gleam", ..] -> True
    _else -> False
  }
  |> should.be_true
}

pub fn packages_test() {
  let input = iterable_input()
  let builder =
    iterable_builder()
    |> task.for(each: task.packages)

  let assert Each(get: items_fun, map: mapper) = builder.for

  let items = items_fun(input, builder)

  items
  |> list.contains("rad")
  |> should.be_true

  items
  |> list.contains("gleam_stdlib")
  |> should.be_true

  let item = mapper(input, builder, 0, ["a"])

  item.args
  |> should.equal(["a"])
}

pub fn targets_test() {
  let input = iterable_input()
  let builder =
    iterable_builder()
    |> task.for(each: task.targets)

  let assert Ok(targets) =
    "target"
    |> flag.get_strings(from: input.flags)

  let assert Each(get: items_fun, map: mapper) = builder.for

  input
  |> items_fun(builder)
  |> should.equal(targets)

  let item = mapper(input, builder, 0, ["erlang"])

  let assert Ok(target) =
    "target"
    |> flag.get_strings(from: item.flags)

  target
  |> should.equal(["erlang"])
}

pub fn or_test() {
  let input = iterable_input()
  let builder =
    iterable_builder()
    |> task.for(
      each: task.packages
      |> task.or(cond: "all", otherwise: task.arguments),
    )

  let assert Each(get: items_fun, ..) = builder.for

  let items = items_fun(input, builder)

  items
  |> should.equal(input.args)

  let assert [first, ..] =
    CommandInput(
      ..input,
      flags: "--all"
      |> flag.update_flags(in: input.flags)
      |> result.unwrap(or: input.flags),
    )
    |> items_fun(builder)

  first
  |> should.equal("rad")
}

fn iterable_builder() {
  let builder =
    []
    |> task.new(run: task.basic(["echo"]))
    |> task.flags(add: iterable_flags())
  Task(
    ..builder,
    config: "gleam.toml"
    |> toml.parse_file
    |> result.lazy_unwrap(or: toml.new)
    |> Parsed,
  )
}

fn iterable_input() {
  let assert Ok(flags) =
    iterable_flags()
    |> dict.from_list
    |> flag.update_flags(with: "--target=erlang,javascript")
  ["a", "b", "c"]
  |> CommandInput(flags: flags, named_args: dict.new())
}

fn iterable_flags() {
  [
    #(
      "rad-test",
      flag.bool()
        |> flag.default(of: True)
        |> flag.build,
    ),
    #(
      "all",
      flag.bool()
        |> flag.default(of: False)
        |> flag.build,
    ),
    #(
      "check",
      flag.bool()
        |> flag.default(of: False)
        |> flag.build,
    ),
    #(
      "target",
      flag.string_list()
        |> flag.default(of: ["erlang"])
        |> flag.build,
    ),
  ]
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
  rad_test.empty_input()
  |> rad_test.run(builder)
  |> should.be_ok

  let builder =
    []
    |> task.new(run: runner)
  rad_test.empty_input()
  |> rad_test.run(builder)
  |> should.be_error
}

pub fn manifest_test() {
  let runner = fn(_input, task: Task(Result)) {
    case task.manifest {
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
    |> task.with_manifest
  rad_test.empty_input()
  |> rad_test.run(builder)
  |> should.be_ok

  let builder =
    []
    |> task.new(run: runner)
  rad_test.empty_input()
  |> rad_test.run(builder)
  |> should.be_error
}

pub fn basic_test() {
  let builder =
    []
    |> task.new(run: task.basic(["echo"]))
  rad_test.empty_input()
  |> rad_test.run(builder)
  |> should.be_ok

  let builder =
    []
    |> task.new(run: task.basic([""]))
  rad_test.empty_input()
  |> rad_test.run(builder)
  |> should.be_error
}

pub fn gleam_test() {
  let builder =
    []
    |> task.new(run: task.gleam([]))

  ["--", "--version"]
  |> rad_test.input(flags: [])
  |> rad_test.run(builder)
  |> should.be_ok

  ["help", "haaalp"]
  |> rad_test.input(flags: [])
  |> rad_test.run(builder)
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
        use maybe_oddish <- result.try(
          arg
          |> int.parse
          |> result.map_error(with: not_oddish),
        )
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
  |> rad_test.input(flags: [])
  |> rad_test.run(builder)
  |> should.equal(Ok("oddish 1"))

  ["1", "2"]
  |> rad_test.input(flags: [])
  |> rad_test.run(builder)
  |> should.be_error

  let args = ["1", "3", "5"]

  args
  |> rad_test.input(flags: [])
  |> rad_test.run(builder)
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
  |> rad_test.input(flags: [])
  |> rad_test.run(builder)
  |> should.equal(Ok(""))

  ["1", "2", "3"]
  |> rad_test.input(flags: [])
  |> rad_test.run(builder)
  |> should.be_error

  let builder =
    []
    |> task.new(run: fn(input, task) {
      let assert Parsed(toml) = task.config
      input.args
      |> toml.decode(from: toml, expect: dynamic.string)
    })
    |> task.with_config

  ["name"]
  |> rad_test.input(flags: [])
  |> rad_test.run(builder)
  |> should.equal(Ok("rad"))

  let builder =
    []
    |> task.new(run: fn(input, task) {
      let assert Parsed(toml) = task.manifest
      input.args
      |> toml.decode(from: toml, expect: dynamic.string)
    })
    |> task.with_manifest

  ["requirements", "gleam_stdlib", "version"]
  |> rad_test.input(flags: [])
  |> rad_test.run(builder)
  |> should.be_ok
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Miscellaneous Functions                //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

pub fn tasks_from_config_test() {
  let tasks =
    task.tasks_from_config()
    |> result.values

  tasks
  |> list.find(one_that: fn(task) {
    case task.path {
      [_at_least, _two, ..] -> True
      _else -> False
    }
  })
  |> should.be_ok

  tasks
  |> list.find(one_that: fn(task) { task.shortdoc != "" })
  |> should.be_ok

  tasks
  |> list.map(with: fn(builder) {
    rad_test.empty_input()
    |> rad_test.run(builder)
  })
  |> result.all
  |> should.be_ok
}

pub fn sort_test() {
  let assert [head, ..rest] =
    standard.workbook()
    |> workbook.to_tasks
    |> list.sized_chunk(into: 3)
    |> list.reverse
    |> list.concat
    |> task.sort

  head.path
  |> should.equal([])

  let assert #(_discard, [_watch, watch_do, ..]) =
    rest
    |> list.split_while(satisfying: fn(task) { task.path != ["watch"] })
  watch_do.path
  |> should.equal(["watch", "do"])
}
