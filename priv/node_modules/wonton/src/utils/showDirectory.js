import { injectContent } from "./index.js";
import { options } from "../index.js";
import path from "path";

export const showDirectory = (response, pathname, contents) => {
  const { live } = options;
  const title = `Index of ${pathname}`;

  contents =
    contents.map(
      (item) =>
        `
      <li><svg class="icon icon-star"><use xlink:href="#icon-star"></use></svg>
        <a href="${path.join(pathname, item)}">${item}</a></li>
    `,
    ).join("\n");

  const content = `
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>${title}</title>
      <style>
        /*! modern-normalize v1.1.0 | MIT License | https://github.com/sindresorhus/modern-normalize */*,::after,::before{box-sizing:border-box}html{-moz-tab-size:4;tab-size:4}html{line-height:1.15;-webkit-text-size-adjust:100%}body{margin:0}body{font-family:system-ui,-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif,'Apple Color Emoji','Segoe UI Emoji'}hr{height:0;color:inherit}abbr[title]{text-decoration:underline dotted}b,strong{font-weight:bolder}code,kbd,pre,samp{font-family:ui-monospace,SFMono-Regular,Consolas,'Liberation Mono',Menlo,monospace;font-size:1em}small{font-size:80%}sub,sup{font-size:75%;line-height:0;position:relative;vertical-align:baseline}sub{bottom:-.25em}sup{top:-.5em}table{text-indent:0;border-color:inherit}button,input,optgroup,select,textarea{font-family:inherit;font-size:100%;line-height:1.15;margin:0}button,select{text-transform:none}[type=button],[type=reset],[type=submit],button{-webkit-appearance:button}::-moz-focus-inner{border-style:none;padding:0}:-moz-focusring{outline:1px dotted ButtonText}:-moz-ui-invalid{box-shadow:none}legend{padding:0}progress{vertical-align:baseline}::-webkit-inner-spin-button,::-webkit-outer-spin-button{height:auto}[type=search]{-webkit-appearance:textfield;outline-offset:-2px}::-webkit-search-decoration{-webkit-appearance:none}::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}summary{display:list-item}
        @import url("https://fonts.googleapis.com/css2?family=Karla:wght@400;700&family=Ubuntu+Mono&display=swap");
        :root {
          --bg: #fff;
          --faff: #ffaff3;
          --fg: #000;
          --accent: #d900b8;
        }
        body, html {
          font-family: "Karla", sans-serif;
          font-size: 17px;
          line-height: 1.4;
          margin: 0;
          min-height: 100vh;
          padding: 0;
          position: relative;
          word-break: break-word;
        }
        body {
          background: var(--bg);
          color: var(--fg);
        }
        body.theme-dark {
          --bg: #292d3e;
          --fg: #e3d8be;
          --accent: var(--faff);
        }
        a, a:visited {
          color: var(--accent);
          text-decoration: none;
        }
        a:hover {
          text-decoration: underline;
        }
        h1, ul {
          margin: 0 2rem 2rem;
        }
        h1 {
          border-bottom: 3px solid var(--faff);
          display: inline-flex;
        }
        ul {
          list-style: none;
          padding: 0;
        }
        li {
          margin-bottom: .5rem;
        }
        .content {
          padding-top: 2rem;
        }
        .icon {
          display: inline-block;
          fill: currentColor;
          height: 1em;
          stroke: currentColor;
          stroke-width: 0;
          width: 1em;
        }
        li > .icon {
          flex-shrink: 0;
          font-size: .7rem;
          margin: 0 0.88rem;
        }
        .svg-lib {
          height: 0;
          overflow: hidden;
          position: absolute;
          width: 0;
        }
      </style>
    </head>
    <body class="theme-dark">
      <script>
        "use strict";
        const bodyClasses = document.body.classList;
        let theme;
        for (const bodyClass of bodyClasses) {
          if (bodyClass.startsWith("theme-")) {
            theme = bodyClass.substr(6);
            bodyClasses.remove(bodyClass);
          }
        }
        try {
          for (const key of Object.keys(localStorage)) {
            if (key.endsWith(".theme")) {
              theme = localStorage.getItem(key);
            }
          }
        } catch {}
        bodyClasses.add(\`theme-\${theme}\`);
      </script>
      <main class="content">
        <h1>${title}</h1>
        <ul>
          ${contents}
        </ul>
      </main>
      <svg class="svg-lib" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
        <defs>
          <symbol id="icon-star" viewBox="0 0 24 24"><path d="M12.897 1.557c-0.092-0.189-0.248-0.352-0.454-0.454-0.495-0.244-1.095-0.041-1.339 0.454l-2.858 5.789-6.391 0.935c-0.208 0.029-0.411 0.127-0.571 0.291-0.386 0.396-0.377 1.029 0.018 1.414l4.623 4.503-1.091 6.362c-0.036 0.207-0.006 0.431 0.101 0.634 0.257 0.489 0.862 0.677 1.351 0.42l5.714-3.005 5.715 3.005c0.186 0.099 0.408 0.139 0.634 0.101 0.544-0.093 0.91-0.61 0.817-1.155l-1.091-6.362 4.623-4.503c0.151-0.146 0.259-0.344 0.292-0.572 0.080-0.546-0.298-1.054-0.845-1.134l-6.39-0.934zM12 4.259l2.193 4.444c0.151 0.305 0.436 0.499 0.752 0.547l4.906 0.717-3.549 3.457c-0.244 0.238-0.341 0.569-0.288 0.885l0.837 4.883-4.386-2.307c-0.301-0.158-0.647-0.148-0.931 0l-4.386 2.307 0.837-4.883c0.058-0.336-0.059-0.661-0.288-0.885l-3.549-3.457 4.907-0.718c0.336-0.049 0.609-0.26 0.752-0.546z"></path></symbol>
        </defs>
      </svg>
    </body>
  `;

  response.writeHead(200, { "Content-Type": "text/html" });
  response.end(live ? injectContent(content) : content, "utf8");
};
