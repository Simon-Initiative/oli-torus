import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import ReactDOM from 'react-dom';
import { clone, parseBoolean } from 'utils/common';
import { JanusCAPIRequestTypes } from './JanusCAPIRequestTypes';
import { CapiIframeModel } from './schema';
import { CapiVariable } from '../../../adaptivity/capi';
import CapiVariablePicker from './CapiVariablePicker';

const CapiIframeAuthor: React.FC<AuthorPartComponentProps<CapiIframeModel>> = (props) => {
  const { model, configuremode, onCancelConfigure, onSaveConfigure } = props;
  const { x, y, z, width, height, src, configData } = model;
  const id: string = props.id;
  const [simFrame, setSimFrame] = useState<HTMLIFrameElement>();
  const messageListener = useRef<any>(null);
  const [inConfigureMode, setInConfigureMode] = useState<boolean>(parseBoolean(configuremode));
  const [configClicked, setconfigClicked] = useState(false);
  const [ready, setReady] = useState<boolean>(false);
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
  }
  interface CapiMessage {
    handshake: CapiHandshake;
    options?: any; // ?? dunno
    type: JanusCAPIRequestTypes;
    values: any; // usually array, but sometimes more?
  }

  const getCleanSimLife = () => ({
    key: '',
    simId: '',
    handshakeMade: false,
    handshake: {
      requestToken: '',
      authToken: props.id,
      config: {},
    },
    init: false,
    ready: false,
    currentState: [],
    ownerActivityId: 0,
  });

  const [simLife, setSimLife] = useState(getCleanSimLife());
  const frameRef = (frame: HTMLIFrameElement) => {
    if (frame) {
      setSimFrame(frame);
    }
  };

  useEffect(() => {
    setInConfigureMode(parseBoolean(configuremode));
  }, [configuremode]);

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

  //Methods for CAPI listener starts from her. Eventually this will move to a common place where authroing and delivery both can share the same JS file

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
    });
    setInternalState(stateVarsFromSim);
  };

  const handleOnReady = (data: any) => {
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
        type,
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

  //Methods for CAPI listener End her

  const handleValueChangeFromModal = (changedVar: any) => {
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
    setconfigClicked(false);
    setInConfigureMode(false);
    const modelClone = clone(model);

    modelClone.configData = internalState;
    onSaveConfigure({
      id,
      snapshot: modelClone,
    });
  };

  const handleEditorCancel = () => {
    if (!inConfigureMode) {
      return;
    } // not mine
    setInConfigureMode(false);
    onCancelConfigure({ id });
    setconfigClicked(false);
  };

  //inConfigureMode = true means user has clicked on the Edit button that opens modal for updating the CAPI variables.
  //configClicked = true means user has clicked on the link to load the capi in auhtoring mode.

  const renderIt = inConfigureMode ? (
    ReactDOM.createPortal(
      <CapiVariablePicker
        label="Stage"
        state={internalState.filter((item: CapiVariable) => !item.readonly)}
        onChange={handleValueChangeFromModal}
        onSave={handleEditorSave}
        onCancel={handleEditorCancel}
      />,
      document.getElementById(props.portal) as Element,
    )
  ) : (
    <React.Fragment>
      <div style={styles}>
        {configClicked ? (
          <iframe
            ref={frameRef}
            style={{ height: '100%', width: '100%' }}
            data-janus-type={tagName}
            src={props.model.src}
            scrolling={props.type?.toLowerCase() === 'janus-capi-iframe' ? 'no' : ''}
          />
        ) : (
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
