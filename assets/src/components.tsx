import * as React from 'react';
import * as ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Maybe, maybe } from 'tsmonad';
import { Editor } from 'components/editing/editor/Editor';
import { configureStore } from 'state/store';

export const registry = {
  Editor,
} as any;

export type ComponentName = keyof typeof registry;

const store = configureStore();

// Expose React/Redux APIs to server-side rendered templates
const component = {
  mount: (componentName: ComponentName, element: HTMLElement, context: any = {}) => {
    maybe(registry[componentName]).lift((Component) => {
      ReactDOM.render(
        <Provider store={store}>
          <Component {...context} />
        </Provider>,
        element,
      );
    });
  },
};
window.component = component;

// Expose other libraries to server-side rendered templates
window.Maybe = Maybe;
declare global {
  interface Window {
    component: typeof component;
    Maybe: typeof Maybe;
  }
}
