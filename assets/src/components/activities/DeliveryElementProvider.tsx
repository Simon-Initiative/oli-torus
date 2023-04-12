import { DeliveryElementProps } from './DeliveryElement';
import { ActivityModelSchema } from './types';
import { WriterContext, defaultWriterContext } from 'data/content/writers/context';
import React, { useContext } from 'react';
import { Maybe } from 'tsmonad';

export interface DeliveryElementState<T extends ActivityModelSchema>
  extends DeliveryElementProps<T> {
  writerContext: WriterContext;
}
const DeliveryElementContext = React.createContext<DeliveryElementState<any> | undefined>(
  undefined,
);
export function useDeliveryElementContext<T extends ActivityModelSchema>() {
  return Maybe.maybe(
    useContext<DeliveryElementState<T> | undefined>(DeliveryElementContext),
  ).valueOrThrow(
    new Error('useDeliveryElementContext must be used within an DeliveryElementProvider'),
  );
}
export const DeliveryElementProvider: React.FC<DeliveryElementProps<any>> = (props) => {
  const writerContext = defaultWriterContext({
    graded: props.context.graded,
    sectionSlug: props.context.sectionSlug,
    projectSlug: props.context.projectSlug,
    bibParams: props.context.bibParams,
    learningLanguage: props.context.learningLanguage,
  });

  return (
    <DeliveryElementContext.Provider value={{ ...props, writerContext }}>
      {props.children}
    </DeliveryElementContext.Provider>
  );
};
