import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import ReactDOM from 'react-dom';
import { clone, parseBoolean } from 'utils/common';
import { JanusCAPIRequestTypes } from './JanusCAPIRequestTypes';
import { CapiIframeModel } from './schema';
import { CapiVariable } from '../../../adaptivity/capi';
import CapiVariablePicker from './CapiVariablePicker';

const CapiIframeAuthor: React.FC<AuthorPartComponentProps<CapiIframeModel>> = (props) => {
  const { onCancelConfigure, onSaveConfigure } = props;
  const [simFrame, setSimFrame] = useState<HTMLIFrameElement>();
  const messageListener = useRef<any>(null);
  const { model, configuremode } = props;
  const [inConfigureMode, setInConfigureMode] = useState<boolean>(parseBoolean(configuremode));
  const { x, y, z, width, height, src, configData } = model;
  const [configClicked, setconfigClicked] = useState(false);
  const [key, setKey] = useState(props.id);
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;
  const [internalState, setInternalState] = useState<any>([]);
  const styles: CSSProperties = {
    width,
    height,
    zIndex: z,
    backgroundColor: 'whitesmoke',
    overflow: 'hidden',
    fontWeight: 'bold',
  };

  const lableStyles: CSSProperties = {
    padding: 0,
    margin: 0,
  };

  const configDivStyles: CSSProperties = {
    padding: 0,
    margin: 0,
  };

  const configAnchorStyles: CSSProperties = {
    padding: 0,
    margin: 0,
    textDecoration: 'none',
    borderBottom: 1,
    borderBottomColor: 'black',
    borderBottomStyle: 'solid',
    cursor: 'pointer',
  };
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
    ownerActivityId: 0,
  });

  const [simLife, setSimLife] = useState(getCleanSimLife());
  interface CapiMessage {
    handshake: CapiHandshake;
    options?: any; // ?? dunno
    type: JanusCAPIRequestTypes;
    values: any; // usually array, but sometimes more?
  }
  useEffect(() => {
    setInConfigureMode(parseBoolean(configuremode));
  }, [configuremode]);
  const frameRef = useCallback((frame) => {
    /* console.log('%c DEBUG FRAME REF CALLBACK', 'background: darkred; color: #fff;', { frame }); */
    if (frame) {
      setSimFrame(frame);
    }
  }, []);
  const initialize = useCallback(async (pModel) => {
    const initResult = await props.onInit({
      id: props.id,
      responses: [],
    });
    setReady(true);
  }, []);

  useEffect(() => {
    initialize(model);
  }, []);
  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, [ready]);
  const sendToIframe = (data: any) => {
    simFrame?.contentWindow?.postMessage(JSON.stringify(data), '*');
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
    sendToIframe(responseMsg);
  };

  const handleHandshakeRequest = (msgData: CapiMessage) => {
    const {
      handshake: { requestToken: msgRequestToken },
    } = msgData;
    simLife.handshakeMade = true;
    simLife.handshake.requestToken = msgRequestToken;

    // taken from simcapi.js TODO move somewhere, use from settings
    simLife.handshake.config = { context: 'AUTHOR' };

    // TODO: here in the handshake response we should send come config...
    sendFormedResponse(simLife.handshake, {}, JanusCAPIRequestTypes.HANDSHAKE_RESPONSE, []);
  };

  const handleValueChange = (msgData: any) => {
    // TODO: is it possible to set "other" values?
    // like session.whatever from here? if so, the following won't work
    const stateVarsFromSim = Object.keys(msgData.values).map((key) => {
      if (!msgData.values[key].readonly) {
        const variableObj: CapiVariable = {
          key: key,
          type: msgData.values[key] ? msgData.values[key].type : null,
          value: msgData.values[key] ? msgData.values[key].value : null,
          allowedValues: msgData.values[key] ? msgData.values[key].allowedValues : null,
          bindTo: msgData.values[key] ? msgData.values[key].bindTo : null,
          readonly: msgData.values[key] ? msgData.values[key].readonly : false,
          writeonly: msgData.values[key] ? msgData.values[key].writeonly : false,
        };
        return variableObj;
      }
    });
    setInternalState(stateVarsFromSim.filter((item) => item !== undefined));
  };

  const handleOnReady = (data: any) => {
    if (simLife.ready) {
      return;
    }
    simLife.ready = true;
    const updateSimLife = { ...simLife };
    updateSimLife.ready = true;
    setSimLife(updateSimLife);
    simLife.currentState.reduce((collect: Record<string, any>, variable: any) => {
      const baseKey = variable.key;
      const value = variable.value;
      const type = variable.type;

      const cVar = new CapiVariable({
        key: baseKey,
        value,
      });
      collect[baseKey] = cVar;
      sendFormedResponse(simLife.handshake, {}, JanusCAPIRequestTypes.VALUE_CHANGE, collect);
      return collect;
    }, {});

    sendFormedResponse(simLife.handshake, {}, JanusCAPIRequestTypes.INITIAL_SETUP_COMPLETE, {});

    return;
  };
  useEffect(() => {
    if (!simFrame) {
      return;
    }
    //console.log('%c DEBUG SIM LIFE RESET', 'background: purple; color: #fff;', { simLife });
    // whenever src changes, need to reset life
    const newLife = getCleanSimLife();
    setSimLife(newLife);

    const configDataState: any = [
      ...configData.map((cdVar: { key: any }) => {
        return { ...cdVar, id: `stage.${id}.${cdVar.key}` };
      }),
    ];
    setInternalState(configDataState);

    simLife.currentState = configDataState;

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

      switch (data.type) {
        case JanusCAPIRequestTypes.HANDSHAKE_REQUEST:
          handleHandshakeRequest(data);
          break;

        case JanusCAPIRequestTypes.ON_READY:
          handleOnReady(data);

          break;
        case JanusCAPIRequestTypes.VALUE_CHANGE:
          handleValueChange(data);
          break;
        default:
          break;
      }
    });
    messageListener.current = messageListenerRef;

    // Introducing listeners requires returning a function that also un-listens
    return () => {
      // unlisten to post message calls
      window.removeEventListener('message', messageListener.current);
    };
  }, [simFrame]);

  const handleValueChangeFromModal = (changedVar: any) => {
    //const filterVars = createCapiObjectFromStateVars(changedVar);
    //sendFormedResponse(simLife.handshake, {}, JanusCAPIRequestTypes.VALUE_CHANGE, changedVar);
    //setInConfigureMode(false);
    const finalConfigData = internalState.map((variable: CapiVariable) => {
      if (variable.key === changedVar.key) {
        variable.value = changedVar.value;
      }
      return variable;
    });
    setInternalState(finalConfigData);
  };
  const handleEditorSave = (changeOperations: any) => {
    if (!inConfigureMode) {
      return;
    }
    console.log('handleEditorSave called', { changeOperations });
    setconfigClicked(false);
    setInConfigureMode(false);
    const modelClone = clone(model);

    modelClone.configData = internalState;
    onSaveConfigure({
      id,
      snapshot: modelClone,
    });
    setKey(`${props.id}_${configClicked}`);
  };

  const handleEditorCancel = () => {
    if (!inConfigureMode) {
      return;
    } // not mine
    // console.log('TF EDITOR CANCEL');
    setInConfigureMode(false);
    onCancelConfigure({ id });
    setconfigClicked(false);
    setKey(`${props.id}_${configClicked}`);
  };

  const renderIt = inConfigureMode ? (
    ReactDOM.createPortal(
      <CapiVariablePicker
        label="Stage"
        state={internalState}
        onChange={handleValueChangeFromModal}
        onSave={handleEditorSave}
        onCancel={handleEditorCancel}
      />,
      document.getElementById(props.portal) as Element,
    )
  ) : (
    <React.Fragment>
      <div style={styles}>
        {configClicked && (
          <iframe
            ref={frameRef}
            style={{ height: '100%', width: '100%' }}
            data-janus-type={tagName}
            src={props.model.src}
            scrolling={props.type?.toLowerCase() === 'janus-capi-iframe' ? 'no' : ''}
          />
        )}
        {!configClicked && (
          <div className="container h-100">
            <div className="row h-100 justify-content-center align-items-center">
              <div>
                <label style={lableStyles}>{props.id}</label>
                {src && !configClicked && (
                  <div style={configDivStyles} className="form-group">
                    <a href="#!" onClick={() => setconfigClicked(true)} style={configAnchorStyles}>
                      configure
                    </a>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </React.Fragment>
  );
  return ready ? renderIt : null;
};

export const tagName = 'janus-capi-iframe';

export default CapiIframeAuthor;
