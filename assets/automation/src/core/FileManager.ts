import path from 'node:path';

export class FileManager {
  static mediaDir(): string {
    return path.resolve(__dirname, '../../tests/resources/media_files');
  }

  static mediaPath(fileName: string): string {
    return path.join(this.mediaDir(), fileName);
  }
}
