import * as React from 'react';
import * as ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { maybe } from 'tsmonad';
import { configureStore } from 'state/store';
import { DarkModeSelector } from 'components/misc/DarkModeSelector';

export const registry = {
  DarkModeSelector,
} as any;

export type ComponentName = keyof typeof registry;

const store = configureStore();

// Expose React/Redux APIs to server-side rendered templates
export const component = {
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
