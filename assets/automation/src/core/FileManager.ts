export class FileManager {
  static getValueEnv(key: string) {
    const value = process.env[key];
    if (value) return value;
    else throw new Error(`Environment variable ${key} is not defined`);
  }
}
