import * as persistence from 'data/persistence/media';

// the server creates a lock on upload, so we must upload files one at a
// time. This factory function returns a new promise to upload a file
// recursively until files is empty
export const uploadFiles = async (projectSlug: string, files: File[]) => {

  const results: any[] = [];

  const uploadFile = async (file: File): Promise<any> =>
    persistence.createMedia(projectSlug, file)
      .then((result) => {

        results.push(result);

        if (files.length > 0) {
          return uploadFile(files.pop() as File);
        }

        return results;
      });

  return uploadFile(files.pop() as File);
};
