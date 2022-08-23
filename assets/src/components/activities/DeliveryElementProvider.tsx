import { Maybe } from 'tsmonad';
import React, { useContext } from 'react';
import { defaultWriterContext, WriterContext } from 'data/content/writers/context';
import { DeliveryElementProps } from './DeliveryElement';

export interface DeliveryElementState<T> extends DeliveryElementProps<T> {
  writerContext: WriterContext;
}
const DeliveryElementContext = React.createContext<DeliveryElementState<any> | undefined>(
  undefined,
);
export function useDeliveryElementContext<T>() {
  return Maybe.maybe(
    useContext<DeliveryElementState<T> | undefined>(DeliveryElementContext),
  ).valueOrThrow(
    new Error('useDeliveryElementContext must be used within an DeliveryElementProvider'),
  );
}
export const DeliveryElementProvider: React.FC<DeliveryElementProps<any>> = (props) => {
  const writerContext = defaultWriterContext({
    sectionSlug: props.context.sectionSlug,
    bibParams: props.context.bibParams,
  });

  return (
    <DeliveryElementContext.Provider value={{ ...props, writerContext }}>
      {props.children}
    </DeliveryElementContext.Provider>
  );
};
