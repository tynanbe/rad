import { Error, Ok, toList } from "./gleam.mjs";
import {
  classify_dynamic,
  map_insert,
  new_map,
} from "../../gleam_stdlib/dist/gleam_stdlib.mjs";
import { DecodeError } from "../../gleam_stdlib/dist/gleam/dynamic.mjs";
import * as TOML from "../priv/node_modules/@ltd/j-toml/index.mjs";
import * as fs from "fs";
import * as path from "path";

const prefix = "./build/dev/javascript";
const ok_signals = [...Array(3)].map((_, i) => i + 385);
const Nil = undefined;

export function decode_object(data) {
  if (typeof data === "object" && !Array.isArray(data) && null !== data) {
    try {
      let map = Object.keys(data).reduce(
        (acc, key) => map_insert(key, data[key], acc),
        new_map(),
      );
      return new Ok(map);
    } catch {}
  }
  let decode_error = new DecodeError(
    "Object",
    classify_dynamic(data),
    toList([]),
  );
  return new Error(toList([decode_error]));
}

export function ebin_paths() {
  let prefix = "./build/dev/erlang";
  try {
    return new Ok(
      toList(
        fs
          .readdirSync(prefix, { withFileTypes: true })
          .filter((item) => item.isDirectory())
          .map((subdir) => [prefix, subdir.name, "ebin"].join("/")),
      ),
    );
  } catch {
    // TODO: improve this?
    return new Error(Nil);
  }
}

export function gleam_run(module) {
  let module_re = new RegExp("(^([.]*/)+|(/[.]*)+$|(/[.]+/)+)", "g");
  module = module.replace(module_re, "");
  let dir = module.replace(new RegExp("/.*$"), "");
  import(path.join("../..", dir, "dist", `${module}.mjs`)).then(
    (module) => module.main(),
  );
  return Nil;
}

export function is_directory(pathname) {
  try {
    return fs.statSync(pathname).isDirectory();
  } catch {
    return false;
  }
}

export function is_file(pathname) {
  try {
    return fs.statSync(pathname).isFile();
  } catch {
    return false;
  }
}

export function mjs_paths() {
  let dist = (dirent) => [prefix, dirent.name, "dist"].join("/");
  try {
    return new Ok(
      toList([
        `${dist({ name: "gleam_stdlib" })}/gleam.mjs`,
        ...fs
          .readdirSync(prefix, { withFileTypes: true })
          .filter((item) => is_directory(dist(item)))
          .map((subdir) => do_mjs_paths(dist(subdir)))
          .flat(),
      ],),
    );
  } catch {
    // TODO: improve this?
    return new Error(Nil);
  }
}

function do_mjs_paths(prefix) {
  return (
    fs
      .readdirSync(prefix, { withFileTypes: true })
      .filter((item) => item.name !== "gleam.mjs")
      .map((item) => {
        let path = `${prefix}/${item.name}`;
        return item.isDirectory() ? do_mjs_paths(path) : path;
      },)
      .flat()
      .filter((item) => item.endsWith(".mjs"))
  );
}

export function load_modules() {
  let re_prefix = prefix.replace(".", "[.]");
  mjs_paths()[0]
    .toArray()
    .map((item) => {
      let name = item.replace(
        new RegExp(`^${re_prefix}/[^/]+/dist/(.*)[.]mjs$`),
        "$$$1",
      ).replace("/", "$");
      item = item.replace(new RegExp(`^${re_prefix}`), "../..");
      return [name, item];
    },)
    .forEach(
      (item) =>
        import(item[1]).then(
          (module) => globalThis[item[0]] = module,
          (_error) => Nil,
        ),
    );
  return Nil;
}

export function recursive_delete(pathname) {
  try {
    fs.rmSync(pathname, { force: true, recursive: true });
    return new Ok(Nil);
  } catch (err) {
    return new Error(err.code);
  }
}

export function rename(source, dest) {
  try {
    fs.renameSync(source, dest);
    return new Ok(Nil);
  } catch (err) {
    return new Error(err.code);
  }
}

export function toml_get(parsed, key_path) {
  let result = new Ok(parsed);
  for (let key of key_path) {
    let value = result[0][key];
    if (value !== Nil) {
      result = new Ok(value);
    } else {
      // TODO: improve this?
      return new Error(Nil);
    }
  }
  return result;
}

export function toml_read_file(pathname) {
  try {
    let content = fs.readFileSync(pathname, "utf-8");
    return new Ok(TOML.parse(content));
  } catch {
    // TODO: improve this?
    return new Error(Nil);
  }
}

export function watch_loop(watch_fun, do_fun) {
  while (true) {
    let result = watch_fun();
    if (result.isOk()) {
      do_fun();
    } else if (ok_signals.includes(result[0][0])) {
      // Exit successfully on some signals.
      break;
    } else {
      return result;
    }
  }
  return new Ok("\n");
}

export function working_directory() {
  try {
    return new Ok(process.cwd());
  } catch {
    // TODO: improve this?
    return new Error(Nil);
  }
}
