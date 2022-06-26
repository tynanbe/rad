const styles = {
  reset: 0,
  black: 30,
  red: 31,
  green: 32,
  yellow: 33,
  blue: 34,
  magenta: 35,
  cyan: 36,
  white: 37,
};

export const style = (name) => {
  const code = name.startsWith("bright") ? styles[name.substr(6)] + 60 : styles[
    name
  ];
  return `\x1b[${code}m`;
};
