import * as fs from "node:fs";
import { encoding, options } from "../index.js";

export const show404 = (response) => {
  fs.readFile(`${options.root}/404.html`, (error, content) => {
    response.writeHead(404, { "Content-Type": "text/html" });
    response.end(content, encoding);
  });
};
