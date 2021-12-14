import { makeRequest } from './common';
function getFileName(file) {
    const fileNameWithDot = file.name.slice(0, file.name.indexOf('.') !== -1 ? file.name.indexOf('.') + 1 : file.name.length);
    const extension = file.name.indexOf('.') !== -1 ? file.name.substr(file.name.indexOf('.') + 1).toLowerCase() : '';
    return fileNameWithDot + extension;
}
function encodeFile(file) {
    const reader = new FileReader();
    if (file) {
        return new Promise((resolve, reject) => {
            reader.addEventListener('load', () => {
                if (reader.result !== null) {
                    resolve(reader.result.substr(reader.result.indexOf(',') + 1));
                }
                else {
                    reject('failed to encode');
                }
            }, false);
            reader.readAsDataURL(file);
        });
    }
    return Promise.reject('file was null');
}
export function createMedia(project, file) {
    const fileName = getFileName(file);
    return encodeFile(file).then((encoding) => {
        const body = {
            file: encoding,
            name: fileName,
        };
        const params = {
            method: 'POST',
            body: JSON.stringify(body),
            url: `/media/project/${project}`,
        };
        return makeRequest(params);
    });
}
export function fetchMedia(project, offset, limit, mimeFilter, urlFilter, searchText, orderBy, order) {
    const query = Object.assign({}, offset ? { offset } : {}, limit ? { limit } : {}, mimeFilter ? { mimeFilter } : {}, urlFilter ? { urlFilter } : {}, searchText ? { searchText } : {}, orderBy ? { orderBy } : {}, order ? { order } : {});
    const params = {
        method: 'GET',
        query,
        url: `/media/project/${project}`,
    };
    return makeRequest(params);
}
//# sourceMappingURL=media.js.map