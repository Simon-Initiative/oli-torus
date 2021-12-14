import { getBaseURL } from './config';
const fetch = window.fetch;
export function makeRequest(params) {
    const method = params.method ? params.method : 'GET';
    const headers = params.headers ? params.headers : { 'Content-Type': 'application/json' };
    const hasTextResult = params.hasTextResult ? params.hasTextResult : false;
    const { body, url, query } = params;
    let queryString = '';
    if (query && Object.keys(query).length > 0) {
        // convert query params to encoded url string
        queryString =
            '?' +
                Object.keys(query)
                    .map((k) => encodeURIComponent(k) + '=' + encodeURIComponent(query[k]))
                    .join('&');
    }
    return new Promise((resolve, reject) => {
        return fetch(getBaseURL() + url + queryString, {
            method,
            headers,
            body,
        })
            .then((response) => {
            if (!response.ok) {
                response.text().then((text) => {
                    // Error responses from the server should always return
                    // objects of type { message: string }
                    let message;
                    try {
                        message = JSON.parse(text);
                        if (message.message !== undefined) {
                            message = message.message;
                        }
                    }
                    catch (e) {
                        message = text;
                    }
                    reject({
                        status: response.status,
                        statusText: response.statusText,
                        message,
                    });
                });
            }
            else {
                resolve(hasTextResult ? response.text() : response.json());
            }
        })
            .catch((error) => {
            reject({
                status: error.status,
                statusText: error.statusText,
                message: error.message,
            });
        });
    });
}
//# sourceMappingURL=common.js.map