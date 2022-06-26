import { networkInterfaces } from "os";

export const getIp = () =>
  Object.values(networkInterfaces())
    .flat()
    .find(
      (ip) => (ip.family === "IPv4" || ip.family === 4) && !ip.internal,
    ).address;
