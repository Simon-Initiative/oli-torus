/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { PartComponentProps } from '../types/parts';
import { ImageModel } from './schema';

const Image: React.FC<PartComponentProps<ImageModel>> = (props) => {
  const [model, setModel] = useState<any>(typeof props.model === 'object' ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const initialize = useCallback(async (pModel) => {
    const initResult = await props.onInit({
      id,
      responses: [],
    });
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
    const pModel = props.model;
    setModel(pModel);
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
    width,
    height,
    /* zIndex: z, */
  };

  return ready ? (
    <img data-janus-type={tagName} draggable="false" alt={alt} src={src} style={imageStyles} />
  ) : null;
};

export const tagName = 'janus-image';

export default Image;
