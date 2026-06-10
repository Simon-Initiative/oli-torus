// Reads a required environment variable and fails fast when it is missing.
export const requireEnv = (name: string) => {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
};

// Reads the first available environment variable from a list of supported names.
export const requireAnyEnv = (names: string[]) => {
  const foundName = names.find((name) => process.env[name]);

  if (!foundName) {
    throw new Error(`Missing required environment variable. Expected one of: ${names.join(', ')}`);
  }

  return process.env[foundName] as string;
};
