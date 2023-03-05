import * as fs from "node:fs";
import * as http from "node:http";
import * as https from "node:https";
import * as path from "node:path";
import process from "node:process";
import listen from "./listen.js";
import {
  checkTlsOptions,
  error,
  getFilePath,
  handleEvent,
  injectContent,
  log,
  mimeType,
  redirect,
  setRoot,
  show404,
  showDirectory,
  showError,
  showFile,
} from "./utils/index.js";

export let options = {
  host: "localhost",
  live: true,
  port: 7000,
  root: ".",
  tls: null,
};

export const defaultRoot = "./public";
export const encoding = "utf-8";
export const eventSource = "/wonton";
export const clients = [];

export const start = (startOptions = {}) => {
  process.on("SIGINT", () => process.exit(0));

  Object.assign(options, startOptions);
  options.root = setRoot();

  const { live, tls } = options;
  let tlsConfig = tls ? checkTlsOptions(tls) : undefined;
  options.protocol = tlsConfig ? "https" : "http";

  let server;
  if (tlsConfig) {
    try {
      server = https.createServer(tlsConfig, handleRequest);
    } catch (e) {
      tlsConfig = checkTlsOptions({}, e);
      options.protocol = "http";
    }
  }
  if (!tlsConfig) {
    server = http.createServer(handleRequest);
  }

  listen(server);

  function handleRequest(request, response) {
    if (live && request.url.startsWith(eventSource)) {
      return handleEvent(request, response);
    }

    const url = new URL(
      request.url,
      `${options.protocol}://${request.headers.host}`,
    );
    const pathname = url.pathname;

    try {
      const lstat = fs.lstatSync(path.join(options.root, pathname));
      if (lstat.isDirectory() && !pathname.endsWith("/")) {
        return redirect(response, 301, `${pathname}/`);
      }
    } catch {}

    const filePath = getFilePath(pathname);

    try {
      const contents = fs.readdirSync(filePath);
      return showDirectory(response, pathname, contents);
    } catch {}

    const extension = path.extname(filePath).toLowerCase().slice(1);
    const contentType = mimeType(extension) || "application/octet-stream";
    const isHtml = contentType == "text/html";
    const encode = isHtml ? "utf8" : null;

    fs.readFile(filePath, encode, (error, content) => {
      if (error) {
        if (error.code == "ENOENT") {
          return show404(response);
        }

        return showError(response, error);
      }

      return showFile(
        response,
        live && isHtml ? injectContent(content) : content,
        contentType,
      );
    });
  }
};

export const update = () => {
  clients.forEach((response) => response.end("data: update\n\n"));
  clients.length = 0;
};

export { error, log };
export default { start, update };
