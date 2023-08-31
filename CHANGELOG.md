# Changelog

## v0.4.0 - 2023-08-31

- Rad now requires Gleam v0.30 or later.
- Rad can now be invoked via `gleam run --target=javascript -m rad`
  (`--target=erlang` is currently unsupported).
- Rad no longer depends on `gleam_erlang` or `gleam_httpc`.

## v0.3.0 - 2023-05-29

- Rad now requires Gleam v0.29 or later.
- Rad now supports `gleam_erlang` v0.19.

## v0.2.2 - 2023-03-21

- Rad now requires `glint` v0.11.1 or later.

## v0.2.1 - 2023-03-05

- Fixed some error messages in the `test` function.

## v0.2.0 - 2023-03-05

- Rad now requires Gleam v0.27 or later.
- Rad now supports the Deno JavaScript runtime (v1.30 or later).
- The `rad/workbook/standard` module gains the `test` function.
- The `javascript_run` function has been updated to accept arguments for both
  the Deno and Node.js runtimes. It will choose which to use based on the
  current project's `gleam.toml` config.
- The `rad/util` module gains the `javascript_runtime` function.

## v0.1.4 - 2022-11-20

- Support Gleam `v0.25`.

## v0.1.3 - 2022-09-23

- Fixed a bug where rad's `gleam_stdlib` requirement was too restrictive.

## v0.1.2 - 2022-08-31

- Fixed a bug where `rad --version` would crash.

## v0.1.1 - 2022-08-29

- Fixed a bug where rad failed to load ebins from symlinked directories.

## v0.1.0 - 2022-08-17

- Initial release!
