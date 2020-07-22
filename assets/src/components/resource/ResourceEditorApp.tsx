import React from 'react';
import ReactDOM from 'react-dom';
import { ResourceEditor } from './ResourceEditor';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { Maybe } from 'tsmonad';
import { configureStore } from 'state/store';

let store = configureStore();

(window as any).oliMountApplication
  = (mountPoint: any, paramString : any) => {
    const params = JSON.parse(atob(paramString));

    ReactDOM.render(
      <Provider store={store}>
        <ResourceEditor {...params} />
        <ModalDisplay/>
      </Provider>,
      mountPoint,
    );
  }

(window as any).store = {
  configureStore: (json: any) => {
    store = configureStore(json);
  },
};

// Expose other libraries to server-side rendered templates
(window as any).Maybe = Maybe;
