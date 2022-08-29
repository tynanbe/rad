import { Error, Ok, toList } from "./gleam.mjs";
import { classify_dynamic } from "../../gleam_stdlib/dist/gleam_stdlib.mjs";
import { DecodeError } from "../../gleam_stdlib/dist/gleam/dynamic.mjs";
import * as shellout from "../../shellout/dist/shellout.mjs";
import * as snag from "../../snag/dist/snag.mjs";
import * as util from "../../rad/dist/rad/util.mjs";
import * as TOML from "../priv/node_modules/@ltd/j-toml/index.mjs";
import * as fs from "fs";
import * as path from "path";

const Nil = undefined;
const LetBeStderr = new shellout.LetBeStderr();
const LetBeStdout = new shellout.LetBeStdout();

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// Runtime Functions                      //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

const prefix = "./build/dev/javascript";
const default_workbook = "../../rad/dist/rad/workbook/standard.mjs";

export function gleam_run(module_name) {
  let config = toml_read_file("./gleam.toml")[0];
  let project = toml_get(config, ["name"])[0];
  let pathname = path.join("../..", project, "dist", `${module_name}.mjs`);
  let run_module = (module) => module.main();
  import(pathname)
    .then(run_module)
    .catch(() => {
      let arguments$ = toList(["build", "--target=javascript"]);
      let options = toList([LetBeStderr, LetBeStdout]);
      shellout.command("gleam", arguments$, ".", options);
      console.log("");
      import(`${pathname}?purge`)
        .then((module) => {
          if ("main" in module) {
            run_module(module);
          } else {
            end_task(`\`${module_name}.main\` not found`);
          }
        })
        .catch(() => end_task(`failed to load module \`${module_name}\``));
    });
  return Nil;
}

function end_task(message) {
  console.log(util.snag_pretty_print(snag.new$(message)));
  import(default_workbook).then((module) => module.main());
}

export function ebin_paths() {
  let prefix = "./build/dev/erlang";
  try {
    return new Ok(
      toList(
        fs
          .readdirSync(prefix)
          .filter((item) => {
            let dir;
            try {
              dir = fs.opendirSync(path.join(prefix, item, "ebin"));
            } catch {
              return false;
            }
            dir.close().catch(() => Nil);
            return true;
          })
          .map((subdir) => path_join(prefix, subdir, "ebin")),
      ),
    );
  } catch {
    return new Error(Nil);
  }
}

function path_join(...paths) {
  let pathname = path.join(...paths);
  return path.isAbsolute(pathname) ? pathname : `.${path.sep}${pathname}`;
}

export function load_modules() {
  let re_prefix = prefix.replace(".", "[.]");
  mjs_paths()[0]
    .toArray()
    .map((item) => {
      let name = item.replace(
        new RegExp(`^${re_prefix}/[^/]+/dist/(.*)[.]mjs$`),
        "$$$1",
      ).replaceAll("/", "$");
      item = item.replace(new RegExp(`^${re_prefix}`), "../..");
      return [name, item];
    })
    .forEach(
      (item) =>
        import(item[1]).then(
          (module) => globalThis[item[0]] = module,
          (_error) => Nil,
        ),
    );
  return Nil;
}

export function mjs_paths() {
  let dist = (dirent) => path_join(prefix, dirent.name, "dist");
  try {
    return new Ok(
      toList([
        path_join(dist({ name: "gleam_stdlib" }), "gleam.mjs"),
        ...fs
          .readdirSync(prefix, { withFileTypes: true })
          .filter((item) => is_directory(dist(item)))
          .map((subdir) => do_mjs_paths(dist(subdir)))
          .flat(),
      ]),
    );
  } catch {
    return new Error(Nil);
  }
}

function do_mjs_paths(prefix) {
  return (
    fs
      .readdirSync(prefix, { withFileTypes: true })
      .filter((item) => "gleam.mjs" !== item.name)
      .map((item) => {
        let pathname = path_join(prefix, item.name);
        return item.isDirectory() ? do_mjs_paths(pathname) : pathname;
      })
      .flat()
      .filter((item) => item.endsWith(".mjs"))
  );
}

const ok_signals = [...Array(3)].map((_, i) => i + 385);

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

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// TOML Functions                         //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

export function decode_object(data) {
  if (typeof data === "object" && !Array.isArray(data) && null !== data) {
    return new Ok(data);
  }
  let decode_error = new DecodeError(
    "Object",
    classify_dynamic(data),
    toList([]),
  );
  return new Error(toList([decode_error]));
}

export function toml_decode_every(toml, key_path, decoder) {
  let result = toml_get(toml, key_path);
  if (!result.isOk()) {
    let decode_error = new DecodeError("field", "nothing", key_path);
    return new Error(toList([decode_error]));
  }
  toml = result[0];
  let items = Object.keys(toml)
    .map((key) => {
      let result = decoder(toml[key]);
      return [key, result.isOk() ? result[0] : Nil];
    })
    .filter(([_key, value]) => Nil !== value);
  return new Ok(toList(items));
}

export function toml_get(parsed, key_path) {
  let result = new Ok(parsed);
  for (let key of key_path) {
    let value = result[0][key];
    if (Nil !== value) {
      result = new Ok(value);
    } else {
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
    return new Error(Nil);
  }
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
// File System Functions                  //
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

export function file_write(contents, pathname) {
  try {
    fs.writeFileSync(pathname, contents);
    return new Ok(Nil);
  } catch (err) {
    return new Error(err);
  }
}

export function is_directory(pathname) {
  try {
    return fs.statSync(pathname).isDirectory();
  } catch {
    return false;
  }
}

export function make_directory(pathname) {
  try {
    fs.mkdirSync(pathname);
    return new Ok(Nil);
  } catch (err) {
    return new Error(err.code);
  }
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

export function working_directory() {
  try {
    return new Ok(process.cwd());
  } catch {
    return new Error(Nil);
  }
}
