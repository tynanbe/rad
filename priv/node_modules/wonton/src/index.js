import {
  checkTLSOptions,
  error,
  getFilePath,
  handleEvent,
  injectContent,
  log,
  mimeType,
  setRoot,
  show404,
  showError,
  showFile,
} from "./utils/index.js";
import listen from "./listen.js";
import fs from "fs";
import http from "http";
import https from "https";
import path from "path";

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
  const tlsConfig = tls ? checkTLSOptions(tls) : undefined;
  const protocol = {
    module: tlsConfig ? https : http,
    alias: tlsConfig ? "https" : "http",
  };
  options.protocol = protocol.alias;

  const server = protocol.module.createServer(
    tlsConfig,
    (request, response) => {
      if (live && request.url.startsWith(eventSource)) {
        return handleEvent(request, response);
      }

      const filePath = getFilePath(request);
      const extension = path.extname(filePath).toLowerCase().slice(1);
      const contentType = mimeType(extension) || "application/octet-stream";
      const isHtml = contentType == "text/html";
      const encode = isHtml ? "utf8" : null;

      fs.readFile(
        filePath,
        encode,
        (error, content) => {
          if (error) {
            if (error.code == "ENOENT") {
              return show404(response);
            }

            return showError(response, error);
          }

          if (live && isHtml) {
            content = injectContent(content);
          }

          return showFile(response, content, contentType);
        },
      );
    },
  );

  listen(server);
};

export const update = () => {
  clients.forEach((response) => response.write("data: update\n\n"));
  clients.length = 0;
};

export { error, log };
export default { start, update };
