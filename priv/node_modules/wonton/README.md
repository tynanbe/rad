# wonton 🥟

[![npm Package](https://img.shields.io/npm/v/wonton?color=ffaff3&label=%F0%9F%93%A6)](https://npmjs.com/package/wonton)
[![License](https://img.shields.io/npm/l/wonton?color=ffaff3&label=%F0%9F%93%83)](https://github.com/tynanbe/wonton/blob/main/LICENSE)
[![Build](https://img.shields.io/github/workflow/status/tynanbe/wonton/CI?color=ffaff3&label=%F0%9F%AB%98)](https://github.com/tynanbe/wonton/actions)

A delightful http server with live reload.

## Features

- Simple CLI and API
- Live reload
- Light and modern
- Secure protocol
- SPA support
- No dependencies

## Run

By default, `wonton` serves `./public/` if the directory exists, otherwise the
current directory `./`. Any directory may be specified instead.

### CLI

```shell
$ npx wonton [options] [path]
```

or

```shell
$ npm install --global wonton
$ wonton \
    --fallback='index.html' \
    --host=0.0.0.0 \
    --live \
    --port=7000 \
    --tls-cert='/absolute/path/to/cert' \
    --tls-key='/absolute/path/to/private_key' \
    -- \
    .
```

### API

```javascript
import serve from "wonton";

serve.start({
  fallback: "index.html",
  host: "localhost",
  live: true,
  port: 7000,
  root: ".",
  tls: {
    cert: "absolute path to cert",
    key: "absolute path to private key",
  },
});
```

## Live Reload

### CLI

```shell
$ curl http://localhost:7000/wonton-update
```

### API

```javascript
serve.update();
```

### Use any file watcher

[Watchexec](https://github.com/watchexec/watchexec)

```shell
$ watchexec -- curl http://localhost:7000/wonton-update
```

[Chokidar](https://github.com/paulmillr/chokidar)

```javascript
import serve from "wonton";
import chokidar from "chokidar";

serve.start();

chokidar.watch(".").on("change", () => {
  serve.update();
});
```

[esbuild](https://esbuild.github.io/api/#watch)
```javascript
import esbuild from "esbuild";
import serve, { error, log } from "wonton";

export const isWatch = process.argv.includes("-w");

const esbuildServe = async (options = {}, serveOptions = {}) => {
  esbuild
    .build({
      ...options,
      watch: isWatch && {
        onRebuild(err) {
          serve.update();
          err ? error("✗ Failed") : log("✓ Updated");
        }
      }
    })
    .catch(() => process.exit(1));

  if (isWatch) {
    serve.start(serveOptions);
  }
};

export default esbuildServe;
```

## Log

Import the util functions to log updates with colours.

```javascript
import serve, { error, log } from "wonton";

serve.update();

hasError
  ? error("✗ Failed") // Red
  : log("✓ Updated"); // Green
```
