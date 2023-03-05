import { readFileSync } from "node:fs";
import { error } from "./error.js";
import { isEmptyObject } from "./fn.js";

export const checkTlsOptions = (object, err) => {
  const validTlsOptions = !isEmptyObject(object) &&
    typeof object.key === "string" &&
    typeof object.cert === "string";

  if (validTlsOptions) {
    try {
      const tlsConfig = {};
      tlsConfig.key = readFileSync(object.key);
      tlsConfig.cert = readFileSync(object.cert);
      return tlsConfig;
    } catch (e) {
      logError(e);
      return undefined;
    }
  } else {
    logError(err ?? new Error("Invalid TLS options"));
    return undefined;
  }
};

function logError(err) {
  error(`
Unable to start HTTPS server
Reason: ${err.message}
`);
}
