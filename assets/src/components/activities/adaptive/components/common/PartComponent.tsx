/* eslint-disable react/prop-types */
import {
  AuthorPartComponentProps,
  CustomProperties,
  PartComponentProps,
} from 'components/parts/types/parts';
import React, { CSSProperties, useContext, useEffect, useRef, useState } from 'react';
import {
  NotificationContext,
  NotificationType,
  subscribeToNotification,
} from '../../../../../apps/delivery/components/NotificationContext';
import { tagName as UnknownTag } from './UnknownPart';

const stubHandler = async () => {
  return;
};

type AuthorProps = AuthorPartComponentProps<CustomProperties>;
type DeliveryProps = PartComponentProps<CustomProperties>;

const PartComponent: React.FC<AuthorProps | DeliveryProps> = (props) => {
  const pusherContext = useContext(NotificationContext);

  const initialStyles: CSSProperties = {
    display: 'block',
    position: 'absolute',
    top: props.model.y,
    left: props.model.x,
    zIndex: props.model.z || 0,
    width: props.model.width,
    height: props.model.overrideHeight ? props.model.height : 'auto',
  };

  const [componentStyle, setComponentStyle] = useState<CSSProperties>(initialStyles);

  const [customCssClass, setCustomCssClass] = useState<string>(props.model.customCssClass || '');
  const handleiFrameStylingChanges = (currentStateSnapshot: Record<string, unknown>) => {
    //janus-capi-iframe is the only component that allows a user to change it's position and some other style attributes
    if (props.type === 'janus-capi-iframe') {
      const externalActivityStyles: CSSProperties = {};
      const sX: any = currentStateSnapshot[`stage.${props.id}.IFRAME_frameX`];
      if (sX !== undefined) {
        externalActivityStyles.left = sX;
      }

      const sY: any = currentStateSnapshot[`stage.${props.id}.IFRAME_frameY`];
      if (sY !== undefined) {
        externalActivityStyles.top = sY;
      }

      const sZ: any = currentStateSnapshot[`stage.${props.id}.IFRAME_frameZ`];
      if (sZ !== undefined) {
        externalActivityStyles.zIndex = sZ;
      }

      const sWidth: any = currentStateSnapshot[`stage.${props.id}.IFRAME_frameWidth`];
      if (sWidth !== undefined) {
        externalActivityStyles.width = sWidth;
      }

      const sHeight: any = currentStateSnapshot[`stage.${props.id}.IFRAME_frameHeight`];
      if (sHeight !== undefined) {
        externalActivityStyles.height = sHeight;
      }
      setComponentStyle({ ...componentStyle, ...externalActivityStyles });

      const sCssClass: any = currentStateSnapshot[`stage.${props.id}.IFRAME_frameCssClass`];
      if (sCssClass !== undefined) {
        setCustomCssClass(sCssClass);
      }
    }
  };
  const wcEvents: Record<string, any> = {
    init: props.onInit,
    ready: props.onReady,
    save: props.onSave,
    submit: props.onSubmit,
    // authoring
    configure: (props as AuthorProps).onConfigure || stubHandler,
    saveconfigure: (props as AuthorProps).onSaveConfigure || stubHandler,
    cancelconfigure: (props as AuthorProps).onCancelConfigure || stubHandler,
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
            if (notificationType === NotificationType.CONTEXT_CHANGED) {
              handleiFrameStylingChanges(e.snapshot);
            }
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
        // TODO: refactor all handlers to take ID and send it here
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

  const webComponentProps: any = {
    ref,
    ...props,
    model: JSON.stringify(props.model),
    state: JSON.stringify(props.state),
    customCssClass,
  };

  let wcTagName = props.type;
  if (!wcTagName || !customElements.get(wcTagName)) {
    wcTagName = UnknownTag;
  }

  // if we pass in style then it will be controlled and so nothing else can use it
  if (!(props as AuthorProps).editMode) {
    webComponentProps.style = componentStyle;
    // console.log('DELIVERY RENDER:', wcTagName, props);
  }

  // don't render until we're listening because otherwise the init event will post too fast
  return listening ? React.createElement(wcTagName, webComponentProps) : null;
};

export default PartComponent;
