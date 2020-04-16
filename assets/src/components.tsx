import * as React from 'react';
import * as ReactDOM from 'react-dom';

import { Provider } from 'react-redux';
import { Maybe, maybe } from 'tsmonad';
import { CountDisplay } from 'components/CountDisplay';
import { CounterButtons } from 'components/CounterButtons';
import { Editor } from 'components/editor/Editor';
import { configureStore } from 'state/store';
import { TestEditor } from 'components/editor/EditorTest';
import { ResourceEditor } from 'components/resource/ResourceEditor';

export const registry = {
  CountDisplay,
  CounterButtons,
  Editor,
  TestEditor,
  ResourceEditor,
} as any;

export type ComponentName = keyof typeof registry;

let store = configureStore();

// Expose React/Redux APIs to server-side rendered templates
(window as any).component = {
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

(window as any).store = {
  configureStore: (json: any) => {
    store = configureStore(json);
  },
};

// Expose other libraries to server-side rendered templates
(window as any).Maybe = Maybe;
