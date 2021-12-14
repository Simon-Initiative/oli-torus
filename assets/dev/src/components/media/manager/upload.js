var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import * as persistence from 'data/persistence/media';
// the server creates a lock on upload, so we must upload files one at a
// time. This factory function returns a new promise to upload a file
// recursively until files is empty
export const uploadFiles = (projectSlug, files) => __awaiter(void 0, void 0, void 0, function* () {
    const results = [];
    const uploadFile = (file) => __awaiter(void 0, void 0, void 0, function* () {
        return persistence.createMedia(projectSlug, file).then((result) => {
            results.push(result);
            if (files.length > 0) {
                return uploadFile(files.pop());
            }
            return results;
        });
    });
    return uploadFile(files.pop());
});
//# sourceMappingURL=upload.js.map