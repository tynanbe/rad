import gleam/list
import gleam/map
import gleam/option
import gleam/string
import gleeunit/should
import rad/task.{Parsed}
import rad/workbook.{Workbook}
import rad_test.{input, run, task}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Workbook Builder Functions             //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

pub fn from_tasks_test() {
  []
  |> workbook.from_tasks
  |> should.equal(workbook.new())

  [
    []
    |> task.new(run: task.basic(["echo"])),
    ["igglybuff"]
    |> task.new(run: task.basic(["echo"])),
    ["jigglypuff", "wigglytuff"]
    |> task.new(run: task.basic(["echo"])),
  ]
  |> workbook.from_tasks
  |> map.size
  |> should.equal(3)
}

pub fn builder_test() {
  ["corsola"]
  |> task.new(run: task.basic(["echo"]))
  |> workbook.task(into: workbook.new())
  |> map.size
  |> should.equal(1)

  workbook.new()
  |> workbook.tasks(add: [])
  |> should.equal(workbook.new())

  let workbook =
    [
      []
      |> task.new(run: task.basic(["echo"])),
      ["cleffa"]
      |> task.new(run: task.basic(["echo"])),
      ["clefairy", "clefable"]
      |> task.new(run: task.basic(["echo"])),
    ]
    |> workbook.tasks(into: workbook.new())

  workbook
  |> map.size
  |> should.equal(3)

  workbook
  |> workbook.delete(delete: ["clefairy", "clefable"])
  |> workbook.delete(delete: [])
  |> map.size
  |> should.equal(1)
}

pub fn to_tasks_test() {
  workbook.new()
  |> workbook.task(
    add: ["staryu"]
    |> task.new(run: task.basic(["echo"])),
  )
  |> workbook.task(
    add: ["starmie"]
    |> task.new(run: task.basic(["echo"])),
  )
  |> workbook.to_tasks
  |> list.length
  |> should.equal(2)
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Help Functions                         //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

fn workbook() -> Workbook {
  workbook.new()
  |> workbook.task(
    add: ["help"]
    |> task.new(run: workbook.help(workbook))
    |> task.with_config,
  )
  |> workbook.task(
    add: ["chansey"]
    |> task.new(run: fn(_info, task) {
      assert Parsed(config) = task.config
      workbook.info(config)
    })
    |> task.with_config,
  )
  |> workbook.task(
    add: ["blissey"]
    |> task.new(run: workbook.help(workbook))
    |> task.with_config,
  )
}

pub fn help_test() {
  let help =
    ["help"]
    |> task(from: workbook())

  ["help"]
  |> input(flags: [])
  |> run(help)
  |> should.be_ok

  ["chansey"]
  |> input(flags: [])
  |> run(help)
  |> should.be_ok

  let help_blissey =
    ["blissey"]
    |> input(flags: [])
    |> run(help)

  help_blissey
  |> should.be_ok

  let blissey =
    ["blissey"]
    |> task(from: workbook())

  ["blissey"]
  |> input(flags: [])
  |> run(blissey)
  |> should.equal(help_blissey)

  []
  |> input(flags: [])
  |> run(help)
  |> should.be_error

  ["snorlax"]
  |> input(flags: [])
  |> run(help)
  |> should.be_error
}

pub fn info_test() {
  let chansey =
    ["chansey"]
    |> task(from: workbook())

  []
  |> input(flags: [])
  |> run(chansey)
  |> should.be_ok
}

pub fn heading_test() {
  let name = "mew"
  name
  |> workbook.heading
  |> should.not_equal(name)
}

pub fn section_test() {
  let section = workbook.section(
    named: "mewtwo",
    when: _,
    enum: [],
    with: fn(_item) { #("", "") },
    styled: map.new(),
    sorted: string.compare,
  )

  True
  |> section
  |> option.to_result(Nil)
  |> should.be_ok

  False
  |> section
  |> option.to_result(Nil)
  |> should.be_error
}
