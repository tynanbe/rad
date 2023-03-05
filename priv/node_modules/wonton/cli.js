#!/usr/bin/env node

import process from "node:process";
import { options, start } from "./src/index.js";

const handleArg = (acc, arg) => {
  acc["root"] = arg;
  return acc;
};

const setProperty = (obj, path, value) => {
  const [head, ...rest] = path;
  if (rest.length === 0) {
    obj[head] = value;
  } else {
    // Ensure the next recursion has an object to work with
    obj[head] = !!obj[head] && obj[head].constructor === Object
      ? obj[head]
      : {};
    setProperty(obj[head], rest, value);
  }
};

let doneFlags = false;
let args = (globalThis.Deno?.args ?? process.argv.slice(2)).reduce(
  (acc, arg) => {
    if (doneFlags || !arg.startsWith("--")) {
      // Handle regular arguments
      return handleArg(acc, arg);
    }
    let [flag, value] = arg.replace(/^-*/, "").split("=");
    if ("" === flag) {
      // All remaining arguments are regular
      doneFlags = true;
      return acc;
    }
    try {
      value = JSON.parse(value);
    } catch {
      let bool = true;
      if (flag.startsWith("no-")) {
        // Handle `--no-` prefixed flags
        bool = false;
        flag = flag.substr(3);
      }
      // Ensure all flags have values
      value = typeof value === "undefined" ? bool : value;
    }
    // Treat flags as hyphen-delimited nested object paths
    setProperty(acc, flag.split("-"), value);
    return acc;
  },
  options,
);

start(args);
