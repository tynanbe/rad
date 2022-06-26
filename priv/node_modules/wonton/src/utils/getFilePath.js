import { options } from "../index.js";
import fs from "fs";

export const getFilePath = (request) => {
  const { root, fallback, protocol } = options;
  const url = new URL(request.url, `${protocol}://${request.headers.host}`);
  const pathname = url.pathname;

  if (pathname == "/") {
    return `${root}/index.html`;
  }

  if (
    fallback &&
    !fs.existsSync(`${root}${pathname}`) &&
    !pathname.endsWith("/")
  ) {
    return `${root}/${fallback}`;
  }

  if (!pathname.includes(".")) {
    const testFilepath = `${root}/${pathname}.html`;

    if (fs.existsSync(testFilepath)) {
      return testFilepath;
    }
  }

  return root + pathname;
};
