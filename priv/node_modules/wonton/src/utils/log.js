import { style } from "./index.js";

export const log = (message, color = style("green")) =>
  console.log(color + message + style("reset"));
