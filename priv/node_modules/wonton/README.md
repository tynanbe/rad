# wonton 🥟

[![npm Package](https://img.shields.io/npm/v/wonton?color=ffaff3&label&labelColor=2f2f2f&logo=npm&logoColor=fefefc)](https://npmjs.com/package/wonton)
[![deno.land/x Package](https://img.shields.io/endpoint?color=ffaff3&label&labelColor=2f2f2f&logo=deno&logoColor=fefefc&url=https%3A%2F%2Fdeno-visualizer.danopia.net%2Fshields%2Flatest-version%2Fx%2Fwonton)](https://deno.land/x/wonton)
[![License](https://img.shields.io/npm/l/wonton?color=ffaff3&label&labelColor=2f2f2f&logo=data:image/svg+xml;base64,PHN2ZyB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgd2lkdGg9IjM0IiBoZWlnaHQ9IjI4IiB2aWV3Qm94PSIwIDAgMzQgMjgiPgo8cGF0aCBmaWxsPSIjZmVmZWZjIiBkPSJNMjcgN2wtNiAxMWgxMnpNNyA3bC02IDExaDEyek0xOS44MjggNGMtMC4yOTcgMC44NDQtMC45ODQgMS41MzEtMS44MjggMS44Mjh2MjAuMTcyaDkuNWMwLjI4MSAwIDAuNSAwLjIxOSAwLjUgMC41djFjMCAwLjI4MS0wLjIxOSAwLjUtMC41IDAuNWgtMjFjLTAuMjgxIDAtMC41LTAuMjE5LTAuNS0wLjV2LTFjMC0wLjI4MSAwLjIxOS0wLjUgMC41LTAuNWg5LjV2LTIwLjE3MmMtMC44NDQtMC4yOTctMS41MzEtMC45ODQtMS44MjgtMS44MjhoLTcuNjcyYy0wLjI4MSAwLTAuNS0wLjIxOS0wLjUtMC41di0xYzAtMC4yODEgMC4yMTktMC41IDAuNS0wLjVoNy42NzJjMC40MjItMS4xNzIgMS41MTYtMiAyLjgyOC0yczIuNDA2IDAuODI4IDIuODI4IDJoNy42NzJjMC4yODEgMCAwLjUgMC4yMTkgMC41IDAuNXYxYzAgMC4yODEtMC4yMTkgMC41LTAuNSAwLjVoLTcuNjcyek0xNyA0LjI1YzAuNjg4IDAgMS4yNS0wLjU2MiAxLjI1LTEuMjVzLTAuNTYyLTEuMjUtMS4yNS0xLjI1LTEuMjUgMC41NjItMS4yNSAxLjI1IDAuNTYyIDEuMjUgMS4yNSAxLjI1ek0zNCAxOGMwIDMuMjE5LTQuNDUzIDQuNS03IDQuNXMtNy0xLjI4MS03LTQuNXYwYzAtMC42MDkgNS40NTMtMTAuMjY2IDYuMTI1LTExLjQ4NCAwLjE3Mi0wLjMxMyAwLjUxNi0wLjUxNiAwLjg3NS0wLjUxNnMwLjcwMyAwLjIwMyAwLjg3NSAwLjUxNmMwLjY3MiAxLjIxOSA2LjEyNSAxMC44NzUgNi4xMjUgMTEuNDg0djB6TTE0IDE4YzAgMy4yMTktNC40NTMgNC41LTcgNC41cy03LTEuMjgxLTctNC41djBjMC0wLjYwOSA1LjQ1My0xMC4yNjYgNi4xMjUtMTEuNDg0IDAuMTcyLTAuMzEzIDAuNTE2LTAuNTE2IDAuODc1LTAuNTE2czAuNzAzIDAuMjAzIDAuODc1IDAuNTE2YzAuNjcyIDEuMjE5IDYuMTI1IDEwLjg3NSA2LjEyNSAxMS40ODR6Ij48L3BhdGg+Cjwvc3ZnPgo=)](https://github.com/tynanbe/wonton/blob/main/LICENSE)
[![Build](https://img.shields.io/github/actions/workflow/status/tynanbe/wonton/ci.yml?branch=main&color=ffaff3&label&labelColor=2f2f2f&logo=github-actions&logoColor=fefefc)](https://github.com/tynanbe/wonton/actions)

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

**Run**

```shell
$ # With Node.js
$ npx wonton [options] [path]

$ # With Deno
$ deno run \
    --allow-net \
    --allow-read \
    --allow-sys \
    --unstable \
    --reload \
    -- https://deno.land/x/wonton/cli.js \
    [options] \
    [path]
```

**Install &amp; Run**

```shell
$ # With Node.js
$ npm install --global wonton

$ # With Deno
$ deno install \
    --allow-net \
    --allow-read \
    --allow-sys \
    --unstable \
    https://deno.land/x/wonton/cli.js

$ # then...
$ wonton \
    --fallback='index.html' \
    --host=0.0.0.0 \
    --live \
    --port=7000 \
    --tls-cert='/absolute/path/to/cert' \
    --tls-key='/absolute/path/to/private_key' \
    -- .
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
        },
      },
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
