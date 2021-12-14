var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { Transforms } from 'slate';
import { uploadFiles } from 'components/media/manager/upload';
import guid from 'utils/guid';
import { image } from 'data/content/model/elements/factories';
export const onPaste = (editor, e, projectSlug) => __awaiter(void 0, void 0, void 0, function* () {
    if (!e.clipboardData) {
        return Promise.resolve();
    }
    // The clipboard item 'type' attr is a mime-type. look for image/xxx.
    // 'Rich' images e.g. from google docs do not work.
    const images = [...e.clipboardData.items].filter(({ type }) => type.includes('image/'));
    if (images.length === 0) {
        return Promise.resolve();
    }
    const files = images
        .map((image) => image.getAsFile())
        // copied images have a default name of "image." This causes duplicate name
        // conflicts on the server, so rename with a GUID.
        .filter((image) => !!image)
        .map((image) => new File([image], image === null || image === void 0 ? void 0 : image.name.replace(/[^.]*/, guid())));
    return uploadFiles(projectSlug, files)
        .then((uploadedFiles) => uploadedFiles.map((file) => file.url).filter((url) => !!url))
        .then((urls) => urls.forEach((url) => Transforms.insertNodes(editor, image(url))));
});
//# sourceMappingURL=paste.js.map