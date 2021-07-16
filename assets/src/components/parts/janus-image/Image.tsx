/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { JanusAbsolutePositioned, JanusCustomCss, PartComponentProps } from '../types/parts';

interface ImageModel extends JanusAbsolutePositioned, JanusCustomCss {
  src: string;
  alt: string;
}

const Image: React.FC<PartComponentProps<ImageModel>> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(typeof props.model === 'object' ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const initialize = useCallback(async (pModel) => {
    const initResult = await props.onInit({
      id,
      responses: [],
    });
    /* console.log('IMAGE INIT', initResult); */
    // setState??
    const currentStateSnapshot = initResult.snapshot;
    setState(currentStateSnapshot);

    setReady(true);
  }, []);

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
        /* console.log(`${notificationType.toString()} notification handled [Image]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // nothing to do for images
            break;
          case NotificationType.CHECK_COMPLETE:
            // nothing to do for images
            break;
          case NotificationType.STATE_CHANGED:
            // nothing to do for images
            // TODO: maybe allow repositioning and changing visiblity, src
            break;
          case NotificationType.CONTEXT_CHANGED:
            // nothing to do for images
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

  useEffect(() => {
    /* console.log('IMAGE PROPS', props); */
    let pModel;
    let pState;
    if (typeof props?.model === 'string') {
      try {
        pModel = JSON.parse(props.model);
        setModel(pModel);
      } catch (err) {
        // bad json, what do?
      }
    }
    if (typeof props?.state === 'string') {
      try {
        pState = JSON.parse(props.state);
        setState(pState);
      } catch (err) {
        // bad json, what do?
      }
    }
    if (!pModel) {
      return;
    }
    initialize(pModel);
  }, [props]);

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);

  const { x, y, z, width, height, src, alt, customCssClass } = model;
  const imageStyles: CSSProperties = {
    position: 'absolute',
    top: y,
    left: x,
    width,
    height,
    zIndex: z,
  };

  return ready ? (
    <img
      data-janus-type={tagName}
      alt={alt}
      src={src}
      className={customCssClass}
      style={imageStyles}
    />
  ) : null;
};

export const tagName = 'janus-image';

export default Image;
