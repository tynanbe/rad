const loopback_re = /^(?:localhost|[0:]+1|(?:[0:]+ffff:)?(?:7f00:1|127(?:\.\d+){1,3}))$/i;

export const isLoopback = (host) => host.search(loopback_re) < 0;
