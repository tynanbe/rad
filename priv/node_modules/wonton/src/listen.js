import { options } from "./index.js";
import logMessage from "./logMessage.js";

const listen = (
  server,
  serverPort = options.port,
  serverHost = options.host,
) => {
  server.listen(serverPort, serverHost, () => {
    const currentPort = server.address().port;
    const currentHost = server.address().address;

    logMessage(currentPort, currentHost);
  }).once("error", () => {
    server.removeAllListeners("listening");
    listen(server, 0);
  });
};

export default listen;
