import { clients, eventSource, update } from "../index.js";
import { addClient } from "./addClient.js";

export const handleEvent = (request, response) => {
  switch (request.url) {
    case eventSource:
      const client = addClient(response);
      return clients.push(client);
    case `${eventSource}-update`:
      update();
      response.writeHead(200, {
        "Cache-Control": "no-cache, no-store",
        "Content-Type": "text/plain",
      });
      return response.end();
    default:
  }
};
