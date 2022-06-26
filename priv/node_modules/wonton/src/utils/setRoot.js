import { options, defaultRoot } from "../index.js";
import fs from "fs";

export const setRoot = () => {
  const { root } = options;
  const isRoot = !root || root == ".";

  return isRoot && fs.existsSync(defaultRoot) ? defaultRoot : root;
};
