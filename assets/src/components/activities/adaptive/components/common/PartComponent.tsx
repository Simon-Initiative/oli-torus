/* eslint-disable react/prop-types */
import chroma from 'chroma-js';
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

  if (props.model.palette) {
    // console.log('PALETTE: ', { props, palette: props.model.palette });
    if (props.model.palette.useHtmlProps) {
      initialStyles.backgroundColor = props.model.palette.backgroundColor;
      initialStyles.borderColor = props.model.palette.borderColor;
      initialStyles.borderWidth = props.model.palette.borderWidth;
      initialStyles.borderStyle = props.model.palette.borderStyle;
      initialStyles.borderRadius = props.model.palette.borderRadius;
    } else {
      initialStyles.borderWidth = `${
        props.model?.palette?.lineThickness ? props.model?.palette?.lineThickness + 'px' : '1px'
      }`;
      initialStyles.borderRadius = '10px';
      initialStyles.borderStyle = 'solid';
      initialStyles.borderColor = `rgba(${
        props.model?.palette?.lineColor || props.model?.palette?.lineColor === 0
          ? chroma(props.model?.palette?.lineColor).rgb().join(',')
          : '255, 255, 255'
      },${props.model?.palette?.lineAlpha})`;
      initialStyles.backgroundColor = `rgba(${
        props.model?.palette?.fillColor || props.model?.palette?.fillColor === 0
          ? chroma(props.model?.palette?.fillColor).rgb().join(',')
          : '255, 255, 255'
      },${props.model?.palette?.fillAlpha})`;
    }
  }

  const [componentStyle, setComponentStyle] = useState<CSSProperties>(initialStyles);

  const [customCssClass, setCustomCssClass] = useState<string>(props.model.customCssClass || '');

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
  }

  // don't render until we're listening because otherwise the init event will post too fast
  return listening ? React.createElement(wcTagName, webComponentProps) : null;
};

export default PartComponent;
