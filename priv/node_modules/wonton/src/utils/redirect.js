export const redirect = (response, status, location) => {
  response.writeHead(status, { Location: location });
  response.end();
};
