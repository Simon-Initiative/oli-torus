import { FileSpec, FileUploadSchema } from './schema';

export const FileUploadActions = {
  editFileSpec(fileSpec: FileSpec) {
    return (model: FileUploadSchema) => {
      model.fileSpec = fileSpec;
    };
  },
};
