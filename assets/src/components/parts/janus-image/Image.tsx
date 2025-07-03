/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { PartComponentProps } from '../types/parts';
import { ImageModel } from './schema';

const Image: React.FC<PartComponentProps<ImageModel>> = (props) => {
  const [_state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(typeof props.model === 'object' ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const [imgSrc, setImgSrc] = useState<string>('');
  const id: string = props.id;
  const initialize = useCallback(async (pModel) => {
    const initResult = await props.onInit({
      id,
      responses: [],
    });
    /* console.log('IMAGE INIT', initResult); */
    if (initResult) {
      const currentStateSnapshot = initResult.snapshot;
      setState(currentStateSnapshot);
    }
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

  const { width, height, src, imageSrc,defaultSrc, alt } = model;
  const imageStyles: CSSProperties = {
    width,
    height,
    /* zIndex: z, */
  };

  useEffect(() => {
    const styleChanges: any = {};
    if (width !== undefined) {
      styleChanges.width = { value: width as number };
    }
    if (height != undefined) {
      styleChanges.height = { value: height as number };
    }

    props.onResize({ id: `${id}`, settings: styleChanges });
  }, [width, height]);
  useEffect(() => {
    //Image Source will take precedence ( if there is an image link present in it). If Image Sorce is blank then it will display image link from src.
    const imageSource = imageSrc?.length && imageSrc != defaultSrc ? imageSrc : src;
    setImgSrc(imageSource);
  }, [model]);
  return ready ? (
    <img data-janus-type={tagName} draggable="false" alt={alt} src={imgSrc} style={imageStyles} />
  ) : null;
};

export const tagName = 'janus-image';

export default Image;
