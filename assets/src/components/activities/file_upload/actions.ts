import { FileUploadSchema, FileSpec } from './schema';

export const FileUploadActions = {
  editFileSpec(fileSpec: FileSpec) {
    return (model: FileUploadSchema) => {
      model.fileSpec = fileSpec;
    };
  },
};
