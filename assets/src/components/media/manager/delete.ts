import * as persistence from 'data/persistence/media';

export const deleteFiles = async (projectSlug: string, files: string[]) => {
  return persistence.deleteMedia(projectSlug, files).then((result) => {
    return result;
  });
};
