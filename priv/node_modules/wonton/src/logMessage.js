import { log, error, getIp, isLoopback, style } from "./utils/index.js";
import { options } from "./index.js";
import net from "net";

const logMessage = (currentPort, currentHost) => {
  const { port, protocol } = options;

  if (currentPort != port) {
    error(`   ✗ Port ${port} is busy, reconfiguring\n`);
  }
  initLog("  Serving", " … ", "(Ctrl+C to quit)");
  initLog(
    "    Local",
    " → ",
    `${protocol}://${formatHost(currentHost)}:${currentPort}`,
  );
  if (isLoopback(currentHost)) {
    initLog(
      "  Network",
      " → ",
      `${protocol}://${formatHost(getIp())}:${currentPort}`,
    );
  }
};

const formatHost = (host) => net.isIPv6(host) ? `[${host}]` : host;

const initLog = (heading, operator, message) => {
  console.log(
    [
      style("magenta"),
      heading,
      style("cyan"),
      operator,
      style("reset"),
      message,
      style("reset"),
    ].join(""),
  );
};

export default logMessage;
