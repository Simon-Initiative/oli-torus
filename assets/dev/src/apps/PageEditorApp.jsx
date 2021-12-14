import React from 'react';
import ReactDOM from 'react-dom';
import PageEditor from './page-editor/PageEditor';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { Maybe } from 'tsmonad';
import { configureStore } from 'state/store';
import { b64DecodeUnicode } from 'utils/decode';
let store = configureStore();
window.oliMountApplication = (mountPoint, paramString) => {
    const params = JSON.parse(b64DecodeUnicode(paramString));
    ReactDOM.render(<Provider store={store}>
      <PageEditor {...params}/>
      <ModalDisplay />
    </Provider>, mountPoint);
};
window.store = {
    configureStore: (json) => {
        store = configureStore(json);
    },
};
// Expose other libraries to server-side rendered templates
window.Maybe = Maybe;
//# sourceMappingURL=PageEditorApp.jsx.map