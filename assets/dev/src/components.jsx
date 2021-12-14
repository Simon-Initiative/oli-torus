import * as React from 'react';
import * as ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Maybe, maybe } from 'tsmonad';
import { Editor } from 'components/editing/editor/Editor';
import { configureStore } from 'state/store';
export const registry = {
    Editor,
};
const store = configureStore();
// Expose React/Redux APIs to server-side rendered templates
window.component = {
    mount: (componentName, element, context = {}) => {
        maybe(registry[componentName]).lift((Component) => {
            ReactDOM.render(<Provider store={store}>
          <Component {...context}/>
        </Provider>, element);
        });
    },
};
// Expose other libraries to server-side rendered templates
window.Maybe = Maybe;
//# sourceMappingURL=components.jsx.map