import * as fs from "node:fs";
import * as path from "node:path";
import { options } from "../index.js";

export const getFilePath = (pathname) => {
  const { root, fallback } = options;
  pathname = path.join(root, pathname);

  try {
    if (!fs.lstatSync(pathname).isDirectory()) {
      throw null;
    }
    const index = path.join(pathname, "index.html");
    if (fs.existsSync(index)) {
      return index;
    }
  } catch {}

  if (fallback && !fs.existsSync(pathname) && !pathname.endsWith("/")) {
    return path.join(root, fallback);
  }

  if (!path.basename(pathname).includes(".")) {
    const maybePathname = `${pathname}.html`;
    if (fs.existsSync(maybePathname)) {
      return maybePathname;
    }
  }

  return pathname;
};
