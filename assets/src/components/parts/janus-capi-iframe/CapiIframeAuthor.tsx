import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import { JanusCAPIRequestTypes } from './JanusCAPIRequestTypes';
import { CapiIframeModel } from './schema';

const CapiIframeAuthor: React.FC<AuthorPartComponentProps<CapiIframeModel>> = (props) => {
  const [simFrame, setSimFrame] = useState<HTMLIFrameElement>();
  const messageListener = useRef<any>(null);
  const { model } = props;
  const { x, y, z, width, height, src } = model;
  const [configClicked, setconfigClicked] = useState(false);
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
  const frameRef = useCallback((frame) => {
    /* console.log('%c DEBUG FRAME REF CALLBACK', 'background: darkred; color: #fff;', { frame }); */
    if (frame) {
      setSimFrame(frame);
    }
  }, []);
  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);
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
  useEffect(() => {
    if (!simFrame) {
      return;
    }
    //console.log('%c DEBUG SIM LIFE RESET', 'background: purple; color: #fff;', { simLife });
    // whenever src changes, need to reset life
    const newLife = getCleanSimLife();
    setSimLife(newLife);

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
          console.log('ON_READY Called');

          break;
        case JanusCAPIRequestTypes.VALUE_CHANGE:
          console.log('VALUE_CHANGE Called');
          break;
        default:
          break;
      }
    });
    messageListener.current = messageListenerRef;

    // Introducing listeners requires returning a function that also un-listens
    return () => {
      /* console.log('%c MESSAGE LISTENER UNLOADED', 'background: darkred; color: #fff;', {
        activityId: id,
      }); */
      // unlisten to post message calls
      window.removeEventListener('message', messageListener.current);
    };
  }, [simFrame]);

  return (
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
  );
};

export const tagName = 'janus-capi-iframe';

export default CapiIframeAuthor;
