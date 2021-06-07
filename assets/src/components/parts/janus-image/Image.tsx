/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
const Image: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
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
      // eslint-disable-next-line
      data-janus-type={props.type}
      alt={alt}
      src={src}
      className={customCssClass}
      style={imageStyles}
    />
  ) : null;
};

export const tagName = 'janus-image';

// TODO: redo web component

export default Image;
