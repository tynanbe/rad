import { readFileSync } from "fs";
import { error } from "./error.js";
import { isEmptyObject } from "./fn.js";

export const checkTLSOptions = (object) => {
  const validTLSOptions =
    !isEmptyObject(object) &&
    typeof object.key === "string" &&
    typeof object.cert === "string";

  if (validTLSOptions) {
    try {
      const tlsConfig = {};
      tlsConfig.key = readFileSync(object.key);
      tlsConfig.cert = readFileSync(object.cert);
      return tlsConfig;
    } catch (e) {
      error("\nUnable to start HTTPS server \n");
      error(`Reason: ${e} \n`);
      return undefined;
    }
  } else {
    error("\nUnable to start HTTPS server. Reason: INVALID TLS Options \n");
    return undefined;
  }
};
