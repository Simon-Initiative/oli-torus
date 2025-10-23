import path from 'node:path';

export class FileManager {
  static getValueEnv(key: string): string {
    const value = process.env[key];
    if (value) return value;
    throw new Error(`Environment variable ${key} is not defined`);
  }

  static mediaDir(): string {
    return path.resolve(__dirname, '../../tests/resources/media_files');
  }

  static mediaPath(fileName: string): string {
    return path.join(this.mediaDir(), fileName);
  }
}
