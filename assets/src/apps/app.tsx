import React from 'react';
import ReactDOM from 'react-dom';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { Maybe } from 'tsmonad';
import { configureStore } from 'state/store';
import { State } from 'state/index';

export function defineApplication<T extends State>(Component: React.FunctionComponent<any>) {
  // TODO, allow a customized, per app state (both initial state and collection of reducers)
  // to be passed into this function, instead of simply using a shared common state
  let store = configureStore();

  (window as any).oliMountApplication = (mountPoint: any, params: any) => {
    let parsedContent: any = {};
    try {
      parsedContent = JSON.parse(atob(params.content));
    } catch (err) {
      // should have been json, error handling
    }
    let parsedActivityTypes: any = [];
    try {
      parsedActivityTypes = JSON.parse(atob(params.activityTypes));
    } catch (err) {
      // should have been json, error handling
    }
    const props = {
      ...params,
      content: parsedContent,
      activityTypes: parsedActivityTypes
    };

    // console.log('MOUNT UP', props);

    ReactDOM.render(
      <Provider store={store}>
        <Component {...props} />
        <ModalDisplay />
      </Provider>,
      mountPoint,
    );
  };

  (window as any).store = {
    configureStore: (json: any) => {
      store = configureStore(json);
    },
  };

  // Expose other libraries to server-side rendered templates
  (window as any).Maybe = Maybe;
}
