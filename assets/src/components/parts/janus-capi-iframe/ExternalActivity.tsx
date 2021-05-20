/* eslint-disable react/prop-types */
import { CapiVariable, CapiVariableTypes, coerceCapiValue } from '../../../adaptivity/capi';
import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import { getJanusCAPIRequestTypeString, JanusCAPIRequestTypes } from './JanusCAPIRequestTypes';
import { parseBool } from '../../../utils/common';

const fakeUserStorage: any = {};
const getFromUserStorage = async (simId: string | number, key: string | number) =>
  fakeUserStorage[simId]?.[key];
const setToUserStorage = async (simId: string | number, key: string | number, value: any) => {
  if (!fakeUserStorage[simId]) {
    fakeUserStorage[simId] = {};
  }
  fakeUserStorage[simId][key] = value;
};
const externalActivityMap: Map<string, any> = new Map();
const getExternalActivityMap = () => {
  const result: any = {};

  externalActivityMap.forEach((value, key) => {
    // TODO: cut out functions?
    result[key] = value;
  });

  return result;
};
// TODO: fix typing
const ExternalActivity: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});

  const id = props.id;
  const {
    x = 0,
    y = 0,
    z = 0,
    width,
    height,
    src,
    title,
    customCssClass,
    configData,
    visible = true,
  } = model;

  useEffect(() => {
    if (typeof props?.model === 'string') {
      setModel(JSON.parse(props.model));
    }
    if (typeof props?.state === 'string') {
      setState(JSON.parse(props.state));
    }
  }, [props]);

  interface CapiHandshake {
    requestToken: string;
    authToken: string;
    version?: string;
    config: any;
    /*
      config:
          context: "VIEWER"
          lessonAttempt: 0
          lessonId: 109535
          questionId: "q:1540493294565:499"
          servicesBaseUrl: "https://api.smartsparrow.com"
          userData:
              givenName: "Ben"
              id: "4261745"
              surname: "Sparks"
  */
  }

  interface CapiMessage {
    handshake: CapiHandshake;
    options?: any; // ?? dunno
    type: JanusCAPIRequestTypes;
    values: any; // usually array, but sometimes more?
  }

  const [initState, setInitState] = useState([]);
  const [frameX, setFrameX] = useState<number>(x || 0);
  const [frameY, setFrameY] = useState<number>(y || 0);
  const [frameZ, setFrameZ] = useState<number>(z || 0);
  const [frameWidth, setFrameWidth] = useState<number>(width || 0);
  const [frameHeight, setFrameHeight] = useState<number>(height || 0);
  const [frameVisible, setFrameVisible] = useState<boolean>(visible);
  const [simFrame, setSimFrame] = useState<HTMLIFrameElement>();
  const [activitySrc, setActivitySrc] = useState<string>(src);
  const messageListener = useRef<any>(null);
  const [simIsInitStatePassedOnce, setSimIsInitStatePassedOnce] = useState(false);

  useEffect(() => {
    setFrameX(model.x);
    setFrameY(model.y);
    setFrameZ(model.z);
    setFrameWidth(model.width);
    setFrameHeight(model.height);
    setFrameVisible(true);
  }, [model]);

  const externalActivityStyles: CSSProperties = {
    position: 'absolute',
    top: frameY,
    left: frameX,
    width: frameWidth,
    height: frameHeight,
    zIndex: frameZ,
    visibility: frameVisible ? 'visible' : 'hidden',
  };
  const frameRef = useCallback((frame) => {
    console.log('%c DEBUG FRAME REF CALLBACK', 'background: darkred; color: #fff;', { frame });
    if (frame) {
      setSimFrame(frame);
    }
  }, []);

  const getCleanSimLife = () => ({
    // these 2 are mysterious
    key: '',
    simId: '',
    // ...
    handshakeMade: false,
    handshake: {
      // should be of type CapiHandshake
      requestToken: '',
      authToken: props.id,
      config: {},
    },
    init: false, // initial setup complete; this might be init state?
    ready: false,
    currentState: [],
  });
  const [simLife, setSimLife] = useState(getCleanSimLife());
  const [internalState, setInternalState] = useState(state || []);

  const sendToIframe = (data: any) => {
    simFrame?.contentWindow?.postMessage(JSON.stringify(data), '*');
  };

  const writeCapiLog = (msg: any, ...rest: any[]) => {
    const boolWriteLog = false;
    let colorStyle = 'background: #222; color: #bada55';
    const [logStyle] = rest;
    const args = rest;
    if (logStyle && logStyle === 1) {
      colorStyle = 'background: #222; color: yellow;';
      args.shift();
    }
    if (logStyle && logStyle === 2) {
      colorStyle = 'background: darkred; color: white;';
      args.shift();
    }
    if (logStyle && logStyle === 3) {
      colorStyle = 'background: blue; color: white;';
      args.shift();
    }
    //help debug during development. set boolWriteLog = false once you are ready to check-in the code
    if (boolWriteLog) console.log(`%c Capi(${id}) - ${msg}`, colorStyle, ...args);
  };
  //#region Capi Handlers
  const updateInternalState = (vars: any[]) => {
    if (vars?.length) {
      let hasDiff = false;
      const mutableState = [...internalState];
      vars.forEach((changedVar) => {
        const existing = mutableState.find((ms) => ms.id === changedVar.id);
        if (!existing) {
          mutableState.push(changedVar);
          hasDiff = true;
          return;
        }
        if (existing.value !== changedVar.value) {
          hasDiff = true;
          existing.value = changedVar.value;
        }
      });
      if (hasDiff) {
        setInternalState(mutableState);
        mutableState.forEach((element) => {
          if (element.id.indexOf(`stage.${id}.`) === 0) {
            externalActivityMap.set(element.id, element);
          }
        });
      }
    }
  };
  const createCapiObjectFromStateVars = (vars: any[]) => {
    return vars
      .filter((v) => v.id.indexOf(`stage.${id}.`) === 0)
      .reduce((capiFormatted, item) => {
        capiFormatted[item.key] = new CapiVariable({
          key: item.key,
          type: item.type,
          value: item.value,
          allowedValues: item.allowedValues,
        });
        return capiFormatted;
      }, {});
  };

  const sendFormedResponse = (
    handshake: CapiHandshake,
    options: any,
    type: JanusCAPIRequestTypes,
    values: any,
  ) => {
    const responseMsg: CapiMessage = {
      handshake,
      options,
      type,
      values,
    };
    writeCapiLog(`Response (${getJanusCAPIRequestTypeString(type)} : ${type}): `, 1, responseMsg);
    sendToIframe(responseMsg);
  };

  const handleHandshakeRequest = (msgData: CapiMessage) => {
    const {
      handshake: { requestToken: msgRequestToken },
    } = msgData;
    simLife.handshakeMade = true;
    simLife.handshake.requestToken = msgRequestToken;

    // taken from simcapi.js TODO move somewhere, use from settings
    const contexts = {
      VIEWER: 'VIEWER',
      REVIEW: 'REVIEW',
      AUTHOR: 'AUTHOR',
      REPORT: 'REPORT',
    };
    simLife.handshake.config = { context: contexts.VIEWER };

    // TODO: here in the handshake response we should send come config...
    sendFormedResponse(simLife.handshake, {}, JanusCAPIRequestTypes.HANDSHAKE_RESPONSE, []);
  };

  const handleOnReady = (data: any) => {
    if (simLife.ready) {
      return;
    }
    const updateSimLife = { ...simLife };
    updateSimLife.ready = true;
    updateSimLife.init = true;
    setSimLife(updateSimLife);
    // should / will sim send onReady more than once??
    const filterVars = createCapiObjectFromStateVars(simLife.currentState);
    if (filterVars && Object.keys(filterVars)?.length !== 0) {
      handleIFrameSpecificProperties(simLife.currentState);
      sendFormedResponse(simLife.handshake, {}, JanusCAPIRequestTypes.VALUE_CHANGE, filterVars);
    }
    sendFormedResponse(simLife.handshake, {}, JanusCAPIRequestTypes.INITIAL_SETUP_COMPLETE, []);

    return;
  };

  const handleGetData = async (msgData: any) => {
    // GET DATA is meant to pull data from user based persistance for a specific sim
    // this data is *not* stored by the current scripting environment (used by adaptivity)
    const { key, simId } = msgData.values;

    simLife.key = key;
    simLife.simId = simId;

    const response: { values: any } = {
      values: {
        simId,
        key,
      },
    };

    try {
      // TODO: this should call an actual API that fetches from user storage
      const val = await getFromUserStorage(simId, key);
      const value = val || {};
      const exists = val !== undefined;
      response.values.responseType = 'success';
      response.values.value = value;
      response.values.exists = exists;
    } catch (err) {
      response.values.responseType = 'error';
      response.values.error = err;
    }

    sendFormedResponse(
      simLife.handshake,
      msgData.options,
      JanusCAPIRequestTypes.GET_DATA_RESPONSE,
      response.values,
    );
  };

  const handleValueChange = (msgData: any) => {
    // TODO: is it possible to set "other" values?
    // like session.whatever from here? if so, the following won't work
    const stateVarsFromSim = Object.keys(msgData.values).map((stateValueKey) => {
      const variableObj = {
        id: `stage.${id}.${stateValueKey}`,
        key: stateValueKey,
        type: msgData.values[stateValueKey] ? msgData.values[stateValueKey].type : null,
        value: msgData.values[stateValueKey] ? msgData.values[stateValueKey].value : null,
      };
      return variableObj;
    }, {} as any);

    // do we *need* to send initial complete every time??
    updateInternalState(stateVarsFromSim);

    // value change is really the only time we should be saving
    props.onSaveActivity({
      activityId: `${id}`,
      partResponses: stateVarsFromSim,
    });
  };

  const handleSetData = async (message: any) => {
    // SET DATA is intended to write to user storage, it expects a response
    const { key, simId, value } = message.values;

    const response: { values: any } = {
      values: {
        simId,
        key,
      },
    };

    try {
      // TODO: this should call a real API to write to user storage
      await setToUserStorage(simId, key, value);
      response.values.responseType = 'success';
      response.values.value = value;
    } catch (err) {
      response.values.responseType = 'error';
      response.values.error = err;
    }

    sendFormedResponse(
      simLife.handshake,
      message.options,
      JanusCAPIRequestTypes.SET_DATA_RESPONSE,
      response.values,
    );
  };

  const handleCheckRequest = (data: any) => {
    // for now send submitActivity for check
    props.onSubmitActivity({
      activityId: `${id}`,
      partResponses: [],
    });
  };

  const handleResizeParentContainer = (data: any) => {
    // check if is positive or negative value
    // do nothing if negative, add if positive
    if (frameWidth && data?.width) {
      let newW = parseFloat(data.width.value);

      newW = newW < frameWidth ? frameWidth : newW;

      setFrameWidth(newW);
    }
    if (frameHeight && data?.height) {
      let newH = parseFloat(data.height.value);

      newH = newH < frameHeight ? frameHeight : newH;

      setFrameHeight(newH);
    }
    sendFormedResponse(
      simLife.handshake,
      {},
      JanusCAPIRequestTypes.RESIZE_PARENT_CONTAINER_RESPONSE,
      {
        messageId: data.messageId,
        responseType: 'success',
      },
    );
  };

  //#endregion

  const handleIFrameSpecificProperties = (stateVars: any[]) => {
    const interested = stateVars.filter((v) => v.id.indexOf(`stage.${id}.`) === 0);

    const visibility = interested.find((v) => v.key === 'IFRAME_frameVisible');
    if (visibility) {
      setFrameVisible(parseBool(visibility.value));
    }
    const xPos = interested.find((v) => v.key === 'IFRAME_frameX');
    if (xPos) {
      setFrameX(xPos.value);
    }
    const yPos = interested.find((v) => v.key === 'IFRAME_frameY');
    if (yPos) {
      setFrameY(yPos.value);
    }
    const zPos = interested.find((v) => v.key === 'IFRAME_frameZ');
    if (zPos) {
      setFrameZ(zPos.value);
    }
    const wVal = interested.find((v) => v.key === 'IFRAME_frameWidth');
    if (wVal) {
      setFrameWidth(wVal.value);
    }
    const hVal = interested.find((v) => v.key === 'IFRAME_frameHeight');
    if (hVal) {
      setFrameHeight(hVal.value);
    }
  };

  const getInterestedVars = (newVars: any[]) => {
    const interested = newVars.filter((ms) => {
      const isMine = ms.id.indexOf(`stage.${id}.`) === 0;
      if (!isMine) {
        return false;
      }
      const internalValue = externalActivityMap.get(ms.id);
      let mineValue = ms.value;
      let intenalVal = internalValue?.value;
      if (ms.type === CapiVariableTypes.BOOLEAN && typeof intenalVal === 'string') {
        mineValue = JSON.stringify(mineValue);
      }
      if (ms.type === CapiVariableTypes.NUMBER && typeof intenalVal === 'string') {
        mineValue = JSON.stringify(mineValue);
      }
      if (
        typeof ms.value === 'object' &&
        Array.isArray(ms.value) &&
        typeof intenalVal === 'string'
      ) {
        intenalVal = coerceCapiValue(intenalVal, ms.type);
        if (Array.isArray(intenalVal) && Array.isArray(mineValue)) {
          return JSON.stringify(intenalVal) !== JSON.stringify(mineValue);
        }
      }
      if (
        typeof ms.value === 'object' &&
        Array.isArray(ms.value) &&
        typeof intenalVal === 'object' &&
        Array.isArray(intenalVal)
      ) {
        return JSON.stringify(intenalVal) !== JSON.stringify(mineValue);
      }
      if (mineValue == '' && intenalVal == null) return false;
      return !internalValue || intenalVal != mineValue;
    });
    return interested;
  };

  useEffect(() => {
    if (!simFrame) {
      return;
    }
    //console.log('%c DEBUG SIM LIFE RESET', 'background: purple; color: #fff;', { simLife });
    // whenever src changes, need to reset life
    const newLife = getCleanSimLife();
    setSimLife(newLife);

    // state should be updated already with init state by the time we get it
    // so here we want to apply configData FIRST, then overwrite it with anything already set in the state
    const newInternalState: any = [
      ...configData.map((cdVar: { key: any }) => {
        return { ...cdVar, id: `stage.${id}.${cdVar.key}` };
      }),
    ];
    //TODO commenting for now. Need to revisit once state structure logic is in place
    /*     state.forEach((stateVar) => {
      const exists = newInternalState.find((iVar: { id: any }) => iVar.id === stateVar.id);
      if (exists) {
        exists.value =
          stateVar?.value?.toString().trim().length > 0 ? stateVar.value : exists.value;
      } else if (
        initState?.length <= 0 ||
        initState?.find((item: any) => item.id === stateVar.id)
      ) {
        newInternalState.push(stateVar);
      } else if (stateVar.value === '[]') {
        //hack for Absorbance
        stateVar.value = '[""]';
        newInternalState.push(stateVar);
      }
    }); */
    setInternalState(newInternalState);

    simLife.currentState = newInternalState;

    /*   console.log('%c CAPI RENDER ************', 'background: navy;color: #fff;', {
      activitySrc,
      ref: simFrame,
      simLife,
      configData,
      newInternalState,
    }); */

    // Catch post messages from our iFrame
    const messageListenerRef = window.addEventListener('message', (evnt) => {
      if (!(simFrame?.contentWindow === evnt.source)) {
        return;
      }
      let data: CapiMessage;
      try {
        data = JSON.parse(evnt.data);
      } catch (e) {
        // not json
        return;
      }
      // TODO: check that we haven't got wires crossed? i.e. requestToken is the same
      // every time after handshake (if more than one on the same page);
      writeCapiLog(`Received (${getJanusCAPIRequestTypeString(data.type)} : ${data.type}): `, {
        data,
      });
      switch (data.type) {
        case JanusCAPIRequestTypes.HANDSHAKE_REQUEST:
          handleHandshakeRequest(data);
          break;

        case JanusCAPIRequestTypes.ON_READY:
          handleOnReady(data);
          break;

        case JanusCAPIRequestTypes.GET_DATA_REQUEST:
          handleGetData(data);
          break;

        case JanusCAPIRequestTypes.VALUE_CHANGE:
          handleValueChange(data);
          break;

        case JanusCAPIRequestTypes.SET_DATA_REQUEST:
          handleSetData(data);
          break;

        case JanusCAPIRequestTypes.CHECK_REQUEST:
          handleCheckRequest(data);
          break;

        case JanusCAPIRequestTypes.RESIZE_PARENT_CONTAINER_REQUEST:
          handleResizeParentContainer(data.values);
          break;

        default:
          break;
      }
    });
    messageListener.current = messageListenerRef;

    // this might instead need to be something that we wait until the sim says is ready?
    // but also just might not need it at all
    props.onReady({ activityId: `${id}`, partResponses: [] });

    // Introducing listeners requires returning a function that also un-listens
    return () => {
      console.log('%c MESSAGE LISTENER UNLOADED', 'background: darkred; color: #fff;', {
        activityId: id,
      });
      // unlisten to post message calls
      window.removeEventListener('message', messageListener.current);
    };
  }, [simFrame]);

  useEffect(() => {
    //TODO commenting for now. Need to revisit once state structure logic is in place
    //updateInternalState(state);
    // setSimIsInitStatePassedOnce(false);
  }, [state]);

  useEffect(() => {
    if (!simLife.ready || simIsInitStatePassedOnce || initState.length <= 0) {
      return;
    }

    // This will send inital data when we navigate to next screen inside that layer
    const filterVars = createCapiObjectFromStateVars(initState);
    if (filterVars && Object.keys(filterVars)?.length !== 0) {
      handleIFrameSpecificProperties(initState);
      sendFormedResponse(simLife.handshake, {}, JanusCAPIRequestTypes.VALUE_CHANGE, filterVars);
    }
    setSimIsInitStatePassedOnce(true);
  }, [simLife, initState, simIsInitStatePassedOnce]);

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return (
    <iframe
      data-janus-type={props.type}
      id={id}
      ref={frameRef}
      className={customCssClass}
      style={externalActivityStyles}
      title={title}
      src={src}
      scrolling={props.type?.toLowerCase() === 'janus-capi-iframe' ? 'no' : ''}
    />
  );
};

export const tagName = 'janus-capi-iframe';

// TODO: redo web component

export default ExternalActivity;
