<h1 id="rad-✨"><a href="#rad-✨"><img alt="rad ✨" src="https://github.com/tynanbe/rad/raw/main/images/rad.svg"></a></h1>

[![Hex Package](https://img.shields.io/hexpm/v/rad?color=ffaff3&label=%F0%9F%93%A6)](https://hex.pm/packages/rad)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3?label=%F0%9F%93%9A)](https://hexdocs.pm/rad/)
[![License](https://img.shields.io/hexpm/l/rad?color=ffaff3&label=%F0%9F%93%83)](https://github.com/tynanbe/rad/blob/main/LICENSE)
[![Build](https://img.shields.io/github/workflow/status/tynanbe/rad/CI?color=ffaff3&label=%E2%9C%A8)](https://github.com/tynanbe/rad/actions)

A flexible task runner companion for the Gleam build manager.

<p align="center" width="100%"><a href="#screenshot" id="screenshot"><img alt="A rad screenshot." src="https://github.com/tynanbe/rad/raw/main/images/rad-screen-01.png" width="300"></a></p>

Rad has a variety of builtin features. Some of the more powerful include serving
documentation and watching the file system. With
[`rad docs serve`](https://hexdocs.pm/rad/rad/workbook/standard.html#docs_serve),
you can build docs for your project and all of its dependencies, and then serve
them together over `HTTP`, like a small-scale [hexdocs](https://hexdocs.pm/)
service specific to your project. Plus, with
[`rad watch`](https://hexdocs.pm/rad/rad/workbook/standard.html#watch) you get
live reloading of any clients connected to the docs server in addition to
automated testing when saving files, for rapid feedback when coding and writing
docs.

Try this `rad` one-liner:

```shell
$ # Press `Ctrl+Z` and use the `fg` command as needed
$ rad docs serve --all --host=0.0.0.0 &; rad watch
```

Then, visit [`localhost:7000`](http://localhost:7000/), or open
`[your machine's LAN IP]:7000` from another device on your network, and watch
what happens when you edit and save one of your project's files!

Rad provides a helpful framework for automating repetitive actions, reducing
mental burden, and lowering the potential for maintenance errors when developing
your Gleam projects.

Make `rad` your own by customizing it to suit your projects and workflows!

## Quick Start

```shell
$ rad help       # Print help information
$ rad shell      # Start an Erlang shell
$ rad shell iex  # Start an Elixir shell
$ rad shell deno # Start a JavaScript shell
$ rad shell node # Start a JavaScript shell
$ rad tree       # Print the file structure
$ rad docs serve # Serve HTML documentation
$ rad watch      # Automate project tasks
```

## Requirements

[Node.js](https://nodejs.org/) is required to run `rad`. Although most `rad`
commands can be executed with the [Erlang](https://www.erlang.org/) runtime,
`rad` will always initialize via the [Node.js](https://nodejs.org/) runtime.

Additionally, some `rad` commands require [Node.js](https://nodejs.org/)
`>= v17.5.0`, for `fetch` support.

## Installation

### Gleam

```shell
$ gleam add rad
```

## Usage

### Basic Usage

You must run `rad` from your project's base directory (where `gleam.toml`
resides).

```shell
$ ./build/packages/rad/priv/rad <subcommand> [flags]
```

For convenience when invoking `rad`, first perform one of the following
operations in a manner consistent with your shell of choice. The goal is to get
`priv/rad` or `priv/rad.ps1` somewhere in your `$PATH`; there are many ways to
accomplish this, these are merely some suggestions.

#### POSIX (Bash-Like)

<details>
<summary><strong>Alias <code>priv/rad</code></strong></summary>

```shell
$ alias rad='./build/packages/rad/priv/rad'
$ # To persist across sessions, add it to your .bashrc or an analogous file
```
</details>

<details>
<summary><strong>Copy <code>priv/rad</code> into your <code>$PATH</code></strong></summary>

```shell
$ sudo cp ./build/packages/rad/priv/rad /usr/local/bin/
```
</details>

<details>
<summary><strong>Link <code>priv/rad</code> into your <code>$PATH</code></strong></summary>

```shell
$ sudo git clone https://github.com/tynanbe/rad.git /usr/local/share/rad
$ sudo ln -s ../share/rad/priv/rad /usr/local/bin/
```
</details>

#### PowerShell

<details>
<summary><strong>Alias <code>priv/rad.ps1</code></strong></summary>

```shell
PS> function rad { ./build/packages/rad/priv/rad.ps1 @Args }
PS> # To persist across sessions, add it to your $profile file
```
</details>

<details>
<summary><strong>Copy <code>priv/rad.ps1</code> into your <code>$env:PATH</code></strong></summary>

```shell
PS> # Create "${HOME}/bin"
PS> New-Item -Type Directory -Force "${HOME}/bin"

PS> # Add "${HOME}/bin" to $env:PATH
PS> $path = "${HOME}/bin"
PS> $sep = ";" # Use ":" for *nix
PS> $paths = $env:PATH -split $sep
PS> if ($paths -notcontains $path) {
      $env:PATH = (@($path) + $paths | where { $_ }) -join $sep
    }
PS> # To persist across sessions, add the previous lines to your $profile file

PS> # Copy rad.ps1
PS> Copy-Item "./build/packages/rad/priv/rad.ps1" -Destination "${HOME}/bin/"
```
</details>

<details>
<summary><strong>Link <code>priv/rad.ps1</code> into your <code>$env:PATH</code></strong></summary>

```shell
PS> # Create "${HOME}/bin"
PS> New-Item -Type Directory -Force "${HOME}/bin"

PS> # Add "${HOME}/bin" to $env:PATH
PS> $path = "${HOME}/bin"
PS> $sep = ";" # Use ":" for *nix
PS> $paths = $env:PATH -split $sep
PS> if ($paths -notcontains $path) {
      $env:PATH = (@($path) + $paths | where { $_ }) -join $sep
    }
PS> # To persist across sessions, add the previous lines to your $profile file

PS> # Create "${HOME}/src"
PS> New-Item -Type Directory -Force "${HOME}/src"

PS> # Clone the rad repository
PS> git clone https://github.com/tynanbe/rad.git "${HOME}/src/rad"

PS> # Link rad.ps1
PS> New-Item -ItemType SymbolicLink -Target "../src/rad/priv/rad.ps1" -Path "${HOME}/bin/rad.ps1"
```
</details>

<br>

After completing one of the previous operations, you should be able to invoke
`rad` as follows.

```shell
$ rad <subcommand> [flags]
```

More information about `rad`'s standard subcommands can be found in
[`rad` hexdocs](https://hexdocs.pm/rad/rad/workbook/standard.html) or with
[`rad help`](https://hexdocs.pm/rad/rad/workbook.html#help).

### Configuration

You can extend `rad` with your project's `gleam.toml` configuration file.

```toml
[rad]
workbook = "workbook"
targets = ["erlang", "javascript"]
with = "javascript"

[[rad.formatters]]
name = "javascript"
check = ["rome", "ci", "--indent-style=space", "src", "test"]
run = ["rome", "format", "--indent-style=space", "--write", "src", "test"]

[[rad.tasks]]
path = ["purple", "heart"]
run = ["echo", "💜 The dream you'll have here is a dream within a dream."]
shortdoc = "💜 The dream you'll have here is a dream within a dream."

[[rad.tasks]]
path = ["sparkles"]
run = ["echo", "✨ It's been a long road getting here..."]

[[rad.tasks]]
path = ["sparkling", "heart"]
run = ["sh", "-c", "echo '💖 I was staring out the window and there it was, just fluttering there...' $(rad version)!"]
```

#### `[rad]`

In the base `rad` table, you can define a custom
[`workbook`](https://hexdocs.pm/rad/rad/workbook/standard.html#workbook) (see
[Advanced Usage](#advanced-usage)), a default array of compilation `targets`
that `rad` tasks like `build` and `test` will cover, and a default runtime for
`rad` to run all tasks `with` (some tasks, like
[`shell`](https://hexdocs.pm/rad/rad/workbook/standard.html#shell), will not
succeed `with` the `erlang` runtime; `javascript` is the default).

#### `[[rad.formatters]]`

The [`rad format`](https://hexdocs.pm/rad/rad/workbook/standard.html#format)
task runs the `gleam` formatter along with any formatters defined in your
`gleam.toml` config via the `rad.formatters` table array. The `name`, `check`,
and `run` fields are all mandatory for each formatter you define.

#### `[[rad.tasks]]`

You can define your own basic tasks via the `rad.tasks` table array. Few
assumptions are made about your environment, so `rad` won't run your commands
through any shell interpreter on its own; however, the scope of your commands is
virtually unlimited, and you're free to specify your shell interpreter of
choice. The `path` and `run` fields are mandatory for each task you define,
while the `shortdoc` field is optional. Both `path` and `run` must be formatted
as arrays of strings; the strings will generally be single words corresponding
to command line arguments. If your task has a `shortdoc`, it will appear in `rad
help` information as long as it has a visible parent `path`.

### Advanced Usage

The standard `rad` workbook module exemplifies how to create a custom
`workbook.gleam` module for your own project.

By providing [`main`](https://hexdocs.pm/rad/rad/workbook/standard.html#main)
and [`workbook`](https://hexdocs.pm/rad/rad/workbook/standard.html#workbook)
functions in your project's `workbook.gleam` file, you can extend `rad`'s
standard
[`workbook`](https://hexdocs.pm/rad/rad/workbook/standard.html#workbook) with
your own or write one entirely from scratch, optionally making it and your
[`Runner`](https://hexdocs.pm/rad/rad/task.html#Runner)s available for any
dependent projects!

### Examples

```gleam
// src/workbook.gleam

import gleam/dynamic
import gleam/json
import gleam/result
import glint.{CommandInput}
import glint/flag
import rad
import rad/task.{Result, Task}
import rad/util
import rad/workbook.{Workbook}
import rad/workbook/standard
import snag

pub fn main() -> Nil {
  workbook()
  |> rad.do_main
}

pub fn workbook() -> Workbook {
  let standard_workbook = standard.workbook()
  assert Ok(root_task) =
    []
    |> workbook.get(from: standard_workbook)
  assert Ok(help_task) =
    ["help"]
    |> workbook.get(from: standard_workbook)

  standard_workbook
  |> workbook.task(
    add: root
    |> task.runner(into: root_task),
  )
  |> workbook.task(
    add: workbook
    |> workbook.help
    |> task.runner(into: help_task),
  )
  |> workbook.task(
    add: ["commit"]
    |> task.new(run: commit)
    |> task.shortdoc("Generate a questionable commit message"),
  )
}

pub fn root(input: CommandInput, task: Task(Result)) -> Result {
  assert Ok(flag.B(ver)) =
    "version"
    |> flag.get_value(from: input.flags)
  case ver {
    True -> standard.root(input, task)
    False -> workbook.help(from: workbook)(input, task)
  }
}

pub fn commit(_input: CommandInput, _task: Task(Result)) -> Result {
  let script =
    "
    fetch('http://whatthecommit.com/index.txt')
      .then(async (response) => [response.status, await response.text()])
      .then(
        ([status, text]) =>
          console.log(JSON.stringify({ status: status, text: text.trim() }))
      );
    "

  try output =
    ["--eval", script]
    |> util.javascript_run(opt: [])

  let snag = snag.new("service unreachable")

  try status =
    output
    |> json.decode(using: dynamic.field(named: "status", of: dynamic.int))
    |> result.replace_error(snag)

  case status < 400 {
    True ->
      output
      |> json.decode(using: dynamic.field(named: "text", of: dynamic.string))
      |> result.replace_error(snag)
    False -> Error(snag)
  }
}
```

#### In the shell

```shell
$ rad commit
Chuck Norris Emailed Me This Patch... I'm Not Going To Question It
```

## Further Reading

For more information on all things `rad`, read the
[hexdocs](https://hexdocs.pm/rad/).
