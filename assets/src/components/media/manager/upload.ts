import * as persistence from 'data/persistence/media';

export const MaxFileUploadSizeMB = 350; // User-friendly number
export const MaxFileUploadSizeBytes = MaxFileUploadSizeMB * 1048576;

// the server creates a lock on upload, so we must upload files one at a
// time. This factory function returns a new promise to upload a file
// recursively until files is empty
export const uploadFiles = async (projectSlug: string, files: File[]) => {
  const results: any[] = [];

  const uploadFile = async (file: File): Promise<any> => {
    if (file.size >= MaxFileUploadSizeBytes) {
      throw new Error('File is too large');
    }

    return persistence.createMedia(projectSlug, file).then((result) => {
      results.push(result);

      if (files.length > 0) {
        return uploadFile(files.pop() as File);
      }

      return results;
    });
  };

  return uploadFile(files.pop() as File);
};

export const uploadSuperActivityFiles = async (directory: string, files: File[]) => {
  const results: any[] = [];

  const uploadFile = async (file: File): Promise<any> => {
    if (file.size >= MaxFileUploadSizeBytes) {
      throw new Error('File is too large');
    }

    return persistence.createSuperActivityMedia(directory, file).then((result) => {
      results.push(result);

      if (files.length > 0) {
        return uploadFile(files.pop() as File);
      }

      return results;
    });
  };

  return uploadFile(files.pop() as File);
};
