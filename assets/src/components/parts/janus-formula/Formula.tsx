import React, { useCallback, useEffect, useState } from 'react';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { Formula as CommonFormula } from '../../common/Formula';
import { PartComponentProps } from '../types/parts';
import { FormulaModel } from './schema';

const Formula: React.FC<PartComponentProps<FormulaModel>> = (props: any) => {
  const [state, setState] = useState<any>({});
  const [model, _setModel] = useState<any>(props.model);
  const [ready, setReady] = useState<boolean>(false);
  const [isFormulaVisible, setIsFormulaVisible] = useState<boolean>(
    props.model.visible === undefined ? true : props.model.visible,
  );
  const id: string = props.id;

  const initialize = useCallback(async (pModel) => {
    await props.onInit({
      id,
      responses: [],
    });
    setReady(true);
  }, []);

  useEffect(() => {
    initialize(model);
  }, [model]);

  useEffect(() => {
    if (!props.notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CHECK_STARTED,
      NotificationType.CHECK_COMPLETE,
      NotificationType.CONTEXT_CHANGED,
      NotificationType.STATE_CHANGED,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        /* console.log(`[TEXTFLOW]: ${notificationType.toString()} notification handled`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // nothing to do
            break;
          case NotificationType.CHECK_COMPLETE:
            {
              const { snapshot } = payload;
              setState(snapshot);
            }
            break;
          case NotificationType.STATE_CHANGED:
            {
              const { mutateChanges: changes } = payload;
              setState({ ...state, ...changes });
              const visible = changes[`stage.${id}.visible`];
              if (visible !== undefined) {
                setIsFormulaVisible(!!visible);
              }
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { snapshot } = payload;
              setState({ ...state, ...snapshot });
              const visible = snapshot[`stage.${id}.visible`];
              if (visible !== undefined) {
                setIsFormulaVisible(!!visible);
              }
            }
            break;
        }
      };
      const unsub = subscribeToNotification(props.notify, notificationType, handler);
      return unsub;
    });
    return () => {
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [props.notify]);

  const { formula, formulaAltText } = model;
  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);
  const isMathML = formula?.trim().startsWith('<math');
  return ready ? (
    <div style={{ display: `${!isFormulaVisible ? 'none' : 'block'}` }}>
      {
        <CommonFormula
          id={id}
          src={formula}
          formulaAltText={formulaAltText}
          subtype={isMathML ? 'mathml' : 'latex'}
        ></CommonFormula>
      }
    </div>
  ) : null;
};

export const tagName = 'janus-formula';

export default Formula;
