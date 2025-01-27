import React, { FC } from 'react';
import { Provider } from 'react-redux';
import { AnyAction, Store } from 'redux';
import { Maybe } from 'tsmonad';
import { ModalDisplay } from 'components/modal/ModalDisplay';

/**
 * Creates a redux store and returns a component that wires up a <Provider>, <ModalDisplay> and <Component>
 *
 * @param Component The target component to be rendering
 * @param name A good debug-name to see in the react-dev-tools
 * @returns The wrapped component
 */
const wrapWithRedux = (Component: FC, name: string, store: Store<any, AnyAction>): FC => {
  const appWrapper = React.memo((props: any) => {
    return (
      <Provider store={store}>
        <Component {...props} />
        <ModalDisplay />
      </Provider>
    );
  });

  // This wrapper will show up in react dev tools as something like registerApplication(ActivityBank)
  appWrapper.displayName = `registerApplication(${name})`;
  return appWrapper;
};

/**
 * Registers a client side react/js application to be used in Phoenix templates via `ReactPhoenix.ClientSide.react_component`
 * This will wrap the component in a redux store and give it a ModalDisplay top level sibling component it then registers
 * that as window.Component.*name*
 *
 * @param name Name of the app to register. Is used in both the key on window.Components and the debugging label in react-dev-tools
 * @param Component Any react component that represents a top-level application
 * @param reduxStore - If provided, this component will be wrapped in a redux provider with the given store
 */
export function registerApplication(
  name: string,
  Component: React.FunctionComponent<any>,
  reduxStore?: Store<any, AnyAction>,
) {
  // FUTURE CONSIDERATION: Currently, all apps use the same common redux store. It may become necessary to customize that in the future.

  console.info('Registering OLI App', name);

  const target = reduxStore ? wrapWithRedux(Component, name, reduxStore) : Component;

  // Expose other libraries to server-side rendered templates
  window.Maybe = Maybe;

  // When calling something like `ReactPhoenix.ClientSide.react_component("Components.ActivityBank", @context)`
  // in a phoenix template, this is how it finds the appropriate component.
  window.Components = window.Components || {};
  window.Components[name] = target;
}

type WindowComponents = Record<string, FC>;
declare global {
  interface Window {
    Maybe: typeof Maybe;
    Components: WindowComponents;
  }
}
