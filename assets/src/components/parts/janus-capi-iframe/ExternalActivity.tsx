/* eslint-disable react/prop-types */
import debounce from 'lodash/debounce';
import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import { CapiVariable, CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { parseBool, parseBoolean } from '../../../utils/common';
import { getJanusCAPIRequestTypeString, JanusCAPIRequestTypes } from './JanusCAPIRequestTypes';

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
  const [ready, setReady] = useState<boolean>(false);
  const [activityChanged, setActivityChanged] = useState(false);
  const [initState, setInitState] = useState<any>(null);
  const [initStateReceived, setInitStateReceived] = useState(false);

  const id: string = props.id;

  // model items, note that we use default values now because
  // the delay from parsing the json means we can't set them from the model immediately
  const [frameX, setFrameX] = useState<number>(0);
  const [frameY, setFrameY] = useState<number>(0);
  const [frameZ, setFrameZ] = useState<number>(0);
  const [frameWidth, setFrameWidth] = useState<number>(0);
  const [frameHeight, setFrameHeight] = useState<number>(0);
  const [frameVisible, setFrameVisible] = useState<boolean>(true);
  const [simFrame, setSimFrame] = useState<HTMLIFrameElement>();
  const [frameSrc, setFrameSrc] = useState<string>('');
  const [frameCssClass, setFrameCssClass] = useState('');

  // these rely on being set every render and the "model" useState value being set
  const { src, title, customCssClass, configData } = model;

  const initialize = useCallback(async (pModel) => {
    // set defaults
    const dCssClass = pModel.customCssClass || frameCssClass;
    setFrameCssClass(dCssClass);

    const dSrc = pModel.src || frameSrc;
    setFrameSrc(dSrc);

    const dX = pModel.x || frameX;
    setFrameX(dX);

    const dY = pModel.y || frameY;
    setFrameY(dY);

    const dZ = pModel.z || frameZ;
    setFrameZ(dZ);

    const dWidth = pModel.width || frameWidth;
    setFrameWidth(dWidth);

    const dHeight = pModel.height || frameHeight;
    setFrameHeight(dHeight);

    const dVisible = pModel.visible === undefined ? frameVisible : !!parseBoolean(pModel.visible);
    setFrameVisible(dVisible);

    const initResult = await props.onInit({
      id,
      responses: [
        {
          key: 'IFRAME_frameVisible',
          type: CapiVariableTypes.BOOLEAN,
          value: dVisible,
        },
        {
          key: 'IFRAME_frameCssClass',
          type: CapiVariableTypes.STRING,
          value: dCssClass,
        },
        {
          key: 'IFRAME_frameX',
          type: CapiVariableTypes.NUMBER,
          value: dX,
        },
        {
          key: 'IFRAME_frameY',
          type: CapiVariableTypes.NUMBER,
          value: dY,
        },
        {
          key: 'IFRAME_frameZ',
          type: CapiVariableTypes.NUMBER,
          value: dZ,
        },
        {
          key: 'IFRAME_frameWidth',
          type: CapiVariableTypes.NUMBER,
          value: dWidth,
        },
        {
          key: 'IFRAME_frameHeight',
          type: CapiVariableTypes.NUMBER,
          value: dHeight,
        },
        {
          key: 'IFRAME_frameSrc',
          type: CapiVariableTypes.STRING,
          value: dSrc,
        },
      ],
    });

    // result of init has a state snapshot with latest (init state applied)
    writeCapiLog('INIT RESULT CAPI', initResult);
    const currentStateSnapshot = initResult.snapshot;

    processInitStateVariable(currentStateSnapshot);
  }, []);

  const processInitStateVariable = (currentStateSnapshot: any) => {
    const sVisible = currentStateSnapshot[`stage.${id}.IFRAME_frameVisible`];
    if (sVisible !== undefined) {
      setFrameVisible(sVisible);
    }

    const sX = currentStateSnapshot[`stage.${id}.IFRAME_frameX`];
    if (sX !== undefined) {
      setFrameX(sX);
    }

    const sY = currentStateSnapshot[`stage.${id}.IFRAME_frameY`];
    if (sY !== undefined) {
      setFrameY(sY);
    }

    const sZ = currentStateSnapshot[`stage.${id}.IFRAME_frameZ`];
    if (sZ !== undefined) {
      setFrameZ(sZ);
    }

    const sWidth = currentStateSnapshot[`stage.${id}.IFRAME_frameWidth`];
    if (sWidth !== undefined) {
      setFrameWidth(sWidth);
    }

    const sHeight = currentStateSnapshot[`stage.${id}.IFRAME_frameHeight`];
    if (sHeight !== undefined) {
      setFrameHeight(sHeight);
    }

    const sCssClass = currentStateSnapshot[`stage.${id}.IFRAME_frameCssClass`];
    if (sCssClass !== undefined) {
      setFrameCssClass(sCssClass);
    }

    const sSrc = currentStateSnapshot[`stage.${id}.IFRAME_frameSrc`];
    if (sSrc !== undefined) {
      setFrameSrc(sSrc);
    }

    // INIT STATE also needs to take in all the sim values
    const interestedSnapshot = Object.keys(currentStateSnapshot).reduce(
      (collect: Record<string, any>, key) => {
        if (key.indexOf(`stage.${id}.`) === 0) {
          collect[key] = currentStateSnapshot[key];
        }
        return collect;
      },
      {},
    );
    setInitState(interestedSnapshot);

    setInitStateReceived(true);
  };

  useEffect(() => {
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

  const messageListener = useRef<any>(null);
  const [simIsInitStatePassedOnce, setSimIsInitStatePassedOnce] = useState(false);

  const externalActivityStyles: CSSProperties = {
    position: 'absolute',
    top: frameY,
    left: frameX,
    width: frameWidth,
    height: frameHeight,
    zIndex: frameZ,
    // writing 'visible' by default will take precedence (inline styles) over
    // any (legacy) override css attempt at hiding it
    visibility: frameVisible ? undefined : 'hidden',
  };

  const frameRef = useCallback((frame) => {
    /* console.log('%c DEBUG FRAME REF CALLBACK', 'background: darkred; color: #fff;', { frame }); */
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
    // TODO: change to a config value?
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
    if (boolWriteLog) {
      // eslint-disable-next-line
      console.log(`%c Capi(${id}) - ${msg}`, colorStyle, ...args);
    }
  };

  const getInterestedVars = (vars: any) => {
    const interested = Object.keys(vars).filter((ms: any) => {
      const isMine = ms.indexOf(`stage.${id}.`) === 0;
      if (!isMine) {
        return false;
      }
      const internalValue = externalActivityMap.get(ms);
      // mineValue is the value that was passed on to this part component
      // internalVal is the value that is stored locally in key-value pair for value changes comparions
      let mineValue = vars[ms];
      let internalVal = internalValue?.value;
      const typeOfMS = typeof vars[ms];
      const typeofInternalVal = typeof internalVal;

      //handle case where internalVal = 'true' and mineValue =true
      if (ms.type === CapiVariableTypes.BOOLEAN && typeofInternalVal === 'string') {
        mineValue = JSON.stringify(mineValue);
      }
      if (ms.type === CapiVariableTypes.NUMBER && typeofInternalVal === 'string') {
        mineValue = JSON.stringify(mineValue);
      }
      // there are cases where mineValue is an array [38] and InternalVal is also array but it is a string array i.e. "[38]"
      // if this is the case then convert it and check if the values are matching and we are done for this key
      if (typeOfMS === 'object' && Array.isArray(vars[ms]) && typeofInternalVal === 'string') {
        internalVal = new CapiVariable({
          key: ms.key,
          type: ms.type,
          value: internalVal,
        });
        if (Array.isArray(internalVal.value) && Array.isArray(mineValue)) {
          return JSON.stringify(internalVal.value) !== JSON.stringify(mineValue);
        }
      }

      // if it reaches here then check if both mineValue and InternalVal are arrays. If Yes then compare and return;
      if (
        typeOfMS === 'object' &&
        Array.isArray(vars[ms]) &&
        typeofInternalVal === 'object' &&
        Array.isArray(internalVal)
      ) {
        return JSON.stringify(internalVal) !== JSON.stringify(mineValue);
      }
      // finally make sure that the values are not blank & null as some time SIM may return null value and it gets saved as blank ('') but in external map it is null
      if (mineValue == '' && internalVal == null) return false;

      return !internalValue || internalVal != mineValue;
    });

    // Now we have filtered list of variables that have changed and  will return the collection
    return interested?.reduce((collect: any, key: string) => {
      collect[key] = vars[key];
      return collect;
    }, {});
  };

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
        /* console.log(`${notificationType.toString()} notification handled [CAPI_IFRAME]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            {
              writeCapiLog('CHECK REQUEST STARTED STATE!!!!', 3, {
                payload,
                simLife,
              });
              sendFormedResponse(
                simLife.handshake,
                {},
                JanusCAPIRequestTypes.CHECK_START_RESPONSE,
                {},
              );
            }
            break;
          case NotificationType.CHECK_COMPLETE:
            {
              writeCapiLog('CHECK REQUEST COMPLETED STATE!!!!', 3, {
                simLife,
                payload,
              });
              // Need to reply to sim with type === 8
              sendFormedResponse(
                simLife.handshake,
                {},
                JanusCAPIRequestTypes.CHECK_COMPLETE_RESPONSE,
                {},
              );
            }
            break;
          case NotificationType.STATE_CHANGED:
            {
              writeCapiLog('MUTATE STATE!!!!', 3, {
                simLife,
                payload,
              });
              const currentMutateStateSnapshot = payload.mutateChanges;
              //udpate the local key-value pair when variables changed by mutation i.e. from outside
              Object.keys(currentMutateStateSnapshot).forEach((key) => {
                externalActivityMap.set(key, currentMutateStateSnapshot[key]);
              });
              processInitStateVariable(currentMutateStateSnapshot);
              setSimIsInitStatePassedOnce(false);
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              writeCapiLog('CONTEXT CHANGED!!!!', 3, {
                simLife,
                payload,
              });
              const currentStateSnapshot = payload.snapshot;
              //send only those variables whose values are changes
              const finalCurrentStateSnapshot = getInterestedVars(currentStateSnapshot);
              processInitStateVariable(finalCurrentStateSnapshot);
              setSimIsInitStatePassedOnce(false);
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
  }, [props.notify, simLife]);

  //#region Capi Handlers
  const updateInternalState = (vars: any[]) => {
    const mutableState = [...internalState];
    if (vars?.length) {
      let hasDiff = false;

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
    return mutableState;
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
    simLife.init = true;
    simLife.ready = true;
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

  const debounceSave = useCallback(
    debounce(
      ({ id, responses }) => {
        props.onSave({
          id,
          responses,
        });
      },
      500,
      { maxWait: 30000, leading: true },
    ),
    [],
  );

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

    const updatedInternalState = updateInternalState(stateVarsFromSim);
    writeCapiLog('VALUE CHANGE INTERNAL STATE', { updatedInternalState, stateVarsFromSim });

    // value change is really the only time we should be saving
    debounceSave({
      id: `${id}`,
      responses: updatedInternalState,
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
    props.onSubmit({
      id: `${id}`,
      responses: [],
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
    const configDataState: any = [
      ...configData.map((cdVar: { key: any }) => {
        return { ...cdVar, id: `stage.${id}.${cdVar.key}` };
      }),
    ];
    // override configData values from init trap state data.
    const newInternalState =
      configDataState?.map((item: any) => {
        const initStateValue = initState[item.id];
        if (initStateValue?.length || initStateValue?.toString()?.length) {
          item.value = initStateValue;
        }
        return item;
      }) || [];

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

    // TODO: set only after SIM says READY???
    setReady(true);

    // Introducing listeners requires returning a function that also un-listens
    return () => {
      /* console.log('%c MESSAGE LISTENER UNLOADED', 'background: darkred; color: #fff;', {
        activityId: id,
      }); */
      // unlisten to post message calls
      window.removeEventListener('message', messageListener.current);
    };
  }, [simFrame]);

  useEffect(() => {
    if (!simLife.ready || simIsInitStatePassedOnce || !initState) {
      return;
    }

    writeCapiLog('INIT STATE APPLIED', 3);

    // This will send inital data when we navigate to next screen inside that layer
    /* const filterVars = createCapiObjectFromStateVars(initState); */
    const initStateVars = Object.keys(initState).reduce((formatted: any, key) => {
      const baseKey = key.replace(`stage.${id}.`, '');
      const value = initState[key];
      const cVar = new CapiVariable({
        key: baseKey,
        value,
      });
      if (baseKey.indexOf('Settings') === -1) formatted[baseKey] = cVar;
      return formatted;
    }, {});
    if (initStateVars && Object.keys(initStateVars)?.length !== 0) {
      sendFormedResponse(simLife.handshake, {}, JanusCAPIRequestTypes.VALUE_CHANGE, initStateVars);
    }
    // for some reason when trap state variable contains 'Settings' then SIM does not behave properly so it needs to be
    // handled different i.e. on first value change filter the 'Settings' variables and send them in another value_change event
    const initStateVarsWithSettingsVariable = Object.keys(initState).reduce(
      (formatted: any, key) => {
        const baseKey = key.replace(`stage.${id}.`, '');
        const value = initState[key];
        const cVar = new CapiVariable({
          key: baseKey,
          value,
        });
        if (baseKey.indexOf('Settings') !== -1) formatted[baseKey] = cVar;
        return formatted;
      },
      {},
    );
    if (
      initStateVarsWithSettingsVariable &&
      Object.keys(initStateVarsWithSettingsVariable)?.length !== 0
    ) {
      sendFormedResponse(
        simLife.handshake,
        {},
        JanusCAPIRequestTypes.VALUE_CHANGE,
        initStateVarsWithSettingsVariable,
      );
    }
    setSimIsInitStatePassedOnce(true);
  }, [simLife, initState, simIsInitStatePassedOnce]);

  return initStateReceived ? (
    <iframe
      data-part-component-type={props.type}
      id={id}
      ref={frameRef}
      className={customCssClass}
      style={externalActivityStyles}
      title={title}
      src={frameSrc}
      scrolling={props.type?.toLowerCase() === 'janus-capi-iframe' ? 'no' : ''}
    />
  ) : null;
};

export const tagName = 'janus-capi-iframe';

export default ExternalActivity;
