import * as fs from "node:fs";
import { defaultRoot, options } from "../index.js";

export const setRoot = () => {
  const { root } = options;
  const isRoot = !root || root == ".";

  return isRoot && fs.existsSync(defaultRoot) ? defaultRoot : root;
};
