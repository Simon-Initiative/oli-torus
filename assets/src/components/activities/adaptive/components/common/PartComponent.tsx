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
  };

  const [componentStyle, setComponentStyle] = useState<CSSProperties>(initialStyles);

  const [customCssClass, setCustomCssClass] = useState<string>(props.model.customCssClass || '');

  const handleStylingChanges = (currentStateSnapshot: Record<string, unknown>) => {
    const styleChanges: CSSProperties = {};
    const sX = currentStateSnapshot[`stage.${props.id}.IFRAME_frameX`];
    if (sX !== undefined) {
      styleChanges.left = sX as number;
    }

    const sY = currentStateSnapshot[`stage.${props.id}.IFRAME_frameY`];
    if (sY !== undefined) {
      styleChanges.top = sY as number;
    }

    const sZ = currentStateSnapshot[`stage.${props.id}.IFRAME_frameZ`];
    if (sZ !== undefined) {
      styleChanges.zIndex = sZ as number;
    }

    const sWidth = currentStateSnapshot[`stage.${props.id}.IFRAME_frameWidth`];
    if (sWidth !== undefined) {
      styleChanges.width = sWidth as number;
    }

    const sHeight = currentStateSnapshot[`stage.${props.id}.IFRAME_frameHeight`];
    if (sHeight !== undefined) {
      styleChanges.height = sHeight as number;
    }
    setComponentStyle((previousStyle) => {
      // don't need to update if there are no changes
      let changed = false;
      Object.keys(styleChanges).forEach((key) => {
        if ((previousStyle as any)[key] !== (styleChanges as any)[key]) {
          changed = true;
        }
      });
      return changed ? { ...previousStyle, ...styleChanges } : previousStyle;
    });

    const sCssClass = currentStateSnapshot[`stage.${props.id}.IFRAME_frameCssClass`];
    if (sCssClass !== undefined) {
      setCustomCssClass(sCssClass as string);
    }

    const sCustomCssClass = currentStateSnapshot[`stage.${props.id}.customCssClass`];
    if (sCustomCssClass !== undefined) {
      setCustomCssClass(sCustomCssClass as string);
    }
  };

  const handleResize = async (payload: any) => {
    const settings = payload.settings;
    const styleChanges: CSSProperties = {};

    if (settings?.width) {
      styleChanges.width = settings.width.value;
    }

    if (settings?.height) {
      styleChanges.height = settings.height.value;
    }

    if (settings?.zIndex) {
      const newZ = settings.zIndex.value;
      styleChanges.zIndex = newZ;
    }

    setComponentStyle((previousStyle) => {
      // don't need to update if there are no changes
      let changed = false;
      Object.keys(styleChanges).forEach((key) => {
        if ((previousStyle as any)[key] !== (styleChanges as any)[key]) {
          changed = true;
        }
      });
      return changed ? { ...previousStyle, ...styleChanges } : previousStyle;
    });

    return true; // TODO: should be "changed" ?
  };

  const [wcEvents, setWcEvents] = useState<Record<string, (payload: any) => Promise<any>>>({
    init: props.onInit,
    ready: props.onReady,
    save: props.onSave,
    submit: props.onSubmit,
    resize: props.onResize,
    getData: props.onGetData || stubHandler,
    setData: props.onSetData || stubHandler,
    // authoring
    configure: (props as AuthorProps).onConfigure || stubHandler,
    saveconfigure: (props as AuthorProps).onSaveConfigure || stubHandler,
    cancelconfigure: (props as AuthorProps).onCancelConfigure || stubHandler,
  });

  useEffect(() => {
    setWcEvents((currentWcEvents) => {
      let changed = false;
      if (currentWcEvents.init !== props.onInit) {
        /* console.log('[PartComponent] init changed'); */
        changed = true;
      }
      if (currentWcEvents.ready !== props.onReady) {
        /* console.log('[PartComponent] ready changed'); */
        changed = true;
      }
      if (currentWcEvents.save !== props.onSave) {
        /* console.log('[PartComponent] save changed'); */
        changed = true;
      }
      if (currentWcEvents.submit !== props.onSubmit) {
        /* console.log('[PartComponent] submit changed'); */
        changed = true;
      }
      if (currentWcEvents.resize !== props.onResize) {
        /* console.log('[PartComponent] resize changed'); */
        changed = true;
      }
      if (currentWcEvents.getData !== props.onGetData) {
        /* console.log('[PartComponent] getData changed'); */
        changed = true;
      }
      if (currentWcEvents.setData !== props.onSetData) {
        /* console.log('[PartComponent] setData changed'); */
        changed = true;
      }
      if (currentWcEvents.configure !== (props as AuthorProps).onConfigure) {
        if (
          (props as AuthorProps).onConfigure === undefined &&
          currentWcEvents.configure !== stubHandler
        ) {
          /* console.log('[PartComponent] configure changed'); */
          changed = true;
        }
      }
      if (currentWcEvents.saveconfigure !== (props as AuthorProps).onSaveConfigure) {
        if (
          (props as AuthorProps).onSaveConfigure === undefined &&
          currentWcEvents.saveconfigure !== stubHandler
        ) {
          /* console.log('[PartComponent] saveconfigure changed'); */
          changed = true;
        }
      }
      if (currentWcEvents.cancelconfigure !== (props as AuthorProps).onCancelConfigure) {
        if (
          (props as AuthorProps).onCancelConfigure === undefined &&
          currentWcEvents.cancelconfigure !== stubHandler
        ) {
          /* console.log('[PartComponent] cancelconfigure changed'); */
          changed = true;
        }
      }
      // don't trigger a re-render if nothing changed
      return !changed
        ? currentWcEvents
        : {
            init: props.onInit,
            ready: props.onReady,
            save: props.onSave,
            submit: props.onSubmit,
            resize: props.onResize,
            getData: props.onGetData || stubHandler,
            setData: props.onSetData || stubHandler,

            // authoring
            configure: (props as AuthorProps).onConfigure || stubHandler,
            saveconfigure: (props as AuthorProps).onSaveConfigure || stubHandler,
            cancelconfigure: (props as AuthorProps).onCancelConfigure || stubHandler,
          };
    });
  }, [
    props.onInit,
    props.onReady,
    props.onSave,
    props.onSubmit,
    props.onResize,
    props.onGetData,
    props.onSetData,
    (props as AuthorProps).onConfigure,
    (props as AuthorProps).onSaveConfigure,
    (props as AuthorProps).onCancelConfigure,
  ]);

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
      NotificationType.CONFIGURE,
      NotificationType.CONFIGURE_SAVE,
      NotificationType.CONFIGURE_CANCEL,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (e: any) => {
        /* console.log(`${notificationType.toString()} notification handled [PC : ${props.id}]`, e); */
        const el = ref.current;
        if (el) {
          if (el.notify) {
            if (
              notificationType === NotificationType.CONTEXT_CHANGED ||
              notificationType === NotificationType.STATE_CHANGED
            ) {
              handleStylingChanges(e.snapshot || e.mutateChanges);
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
      if (!e.detail) {
        return;
      }
      const { payload, callback } = e.detail;
      if (payload.id !== props.id) {
        // because we need to listen to document we'll get all part component events
        // each PC adds a listener, so we need to filter out our own here
        return;
      }
      const handler = wcEvents[e.type];
      if (handler) {
        // TODO: refactor all handlers to take ID and send it here
        // console.log(`${e.type} event handled [PC : ${props.id}]`, e);
        try {
          const result = await handler(payload);
          if (e.type === 'resize') {
            handleResize(payload);
          }
          if (callback) {
            callback(result);
          }
        } catch (error) {
          console.error('Error in PC handler', { error, type: e.type, payload, callback, handler });
        }
      }
    };
    Object.keys(wcEvents).forEach((eventName) => {
      document.addEventListener(eventName, wcEventHandler);
    });
    /* console.log(`${props.id} listening for events`); */
    setIsListening(true);
    return () => {
      /* console.log(`${props.id} stopped listening for events`); */
      setIsListening(false);
      Object.keys(wcEvents).forEach((eventName) => {
        document.removeEventListener(eventName, wcEventHandler);
      });
    };
  }, [wcEvents]);

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
