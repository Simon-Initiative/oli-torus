/* eslint-disable react/prop-types */
import { PartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useContext, useEffect, useRef, useState } from 'react';
import {
  NotificationContext,
  NotificationType,
  subscribeToNotification,
} from '../../../../../apps/delivery/components/NotificationContext';
import { tagName as UnknownTag } from './UnknownPart';

const PartComponent: React.FC<PartComponentProps<any>> = (props) => {
  const pusherContext = useContext(NotificationContext);

  // TODO: build from configuration instead
  const wcEvents: any = {
    init: props.onInit,
    ready: props.onReady,
    save: props.onSave,
    submit: props.onSubmit,
  };

  const ref = useRef<any>(null);
  useEffect(() => {
    if (!pusherContext) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CHECK_STARTED,
      NotificationType.CHECK_COMPLETE,
      NotificationType.CONTEXT_CHANGED,
      NotificationType.STATE_CHANGED,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (e: any) => {
        /* console.log(`${notificationType.toString()} notification handled [PC : ${props.id}]`, e); */
        const el = ref.current;
        if (el) {
          if (el.notify) {
            el.notify(notificationType.toString(), e);
          }
        }
      };
      const unsub = subscribeToNotification(pusherContext, notificationType, handler);
      return unsub;
    });
    return () => {
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [pusherContext]);

  const [listening, setIsListening] = useState(false);
  useEffect(() => {
    const wcEventHandler = async (e: any) => {
      const { payload, callback } = e.detail;
      if (payload.id !== props.id) {
        // because we need to listen to document we'll get all part component events
        // each PC adds a listener, so we need to filter out our own here
        return;
      }
      const handler = wcEvents[e.type];
      if (handler) {
        const result = await handler(payload);
        if (callback) {
          callback(result);
        }
      }
    };
    Object.keys(wcEvents).forEach((eventName) => {
      document.addEventListener(eventName, wcEventHandler);
    });
    setIsListening(true);
    return () => {
      Object.keys(wcEvents).forEach((eventName) => {
        document.removeEventListener(eventName, wcEventHandler);
      });
    };
  }, []);

  const compStyles: CSSProperties = {
    display: 'block',
  };

  if (props.model) {
    compStyles.position = 'absolute';
    compStyles.top = props.model.y;
    compStyles.left = props.model.x;
    compStyles.zIndex = props.model.z || 0;
    compStyles.width = props.model.width;

    // almost always height is meant to be auto, when not we'll have to let
    // the component handle it
    // compStyles.height = props.model.height;
  }

  const webComponentProps = {
    ref,
    ...props,
    model: JSON.stringify(props.model),
    state: JSON.stringify(props.state),
    style: compStyles,
    class: props.model.customCssClass || '',
  };

  let wcTagName = props.type;
  if (!wcTagName || !customElements.get(wcTagName)) {
    wcTagName = UnknownTag;
  }

  // don't render until we're listening because otherwise the init event will post too fast
  return listening ? React.createElement(wcTagName, webComponentProps) : null;
};

export default PartComponent;
