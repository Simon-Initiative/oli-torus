import React, { useContext } from 'react';
import { Maybe } from 'tsmonad';
import { WriterContext, defaultWriterContext } from 'data/content/writers/context';
import { ActivityErrorDisplay } from './ActivityErrorDisplay';
import { DeliveryElementProps } from './DeliveryElement';
import { ActivityModelSchema } from './types';
import { useDeliveryErrorHandlers } from './useDeliveryErrorHandlers';

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
  const { onSaveActivity, onSavePart, onSubmitActivity, onResetActivity, onSubmitPart, error } =
    useDeliveryErrorHandlers(props);

  const writerContext = defaultWriterContext({
    graded: props.context.graded,
    resourceId: props.context.resourceId,
    sectionSlug: props.context.sectionSlug,
    projectSlug: props.context.projectSlug,
    bibParams: props.context.bibParams,
    learningLanguage: props.context.learningLanguage,
    resourceAttemptGuid: props.context.pageAttemptGuid,
    renderPointMarkers: props.context.renderPointMarkers,
    isBlockLevel: props.context.isBlockLevel,
  });

  return (
    <DeliveryElementContext.Provider
      value={{
        ...props,
        writerContext,
        onSaveActivity,
        onSavePart,
        onSubmitActivity,
        onResetActivity,
        onSubmitPart,
      }}
    >
      <ActivityErrorDisplay error={error}>{props.children}</ActivityErrorDisplay>
    </DeliveryElementContext.Provider>
  );
};
