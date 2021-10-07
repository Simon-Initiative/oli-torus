import {configureStore} from "state/store";
import React, {useEffect, useState} from "react";
import {Heading} from "components/misc/Heading";

import {OliEmbeddedModelSchema} from "components/activities/oli_embedded/schema";
import ReactDOM from "react-dom";
import {Provider} from "react-redux";
import * as ActivityTypes from "components/activities/types";
import {
  DeliveryElement,
  DeliveryElementProps,
  DeliveryElementProvider,
  useDeliveryElementContext
} from "components/activities/DeliveryElement";
import {activityDeliverySlice} from "data/activities/DeliveryState";
// import {getCookie} from "components/cookies/utils";
// import {activityDeliverySlice, initializeState} from "data/content/activities/DeliveryState";

interface Context {
  src_url: string,
  activity_type: string,
  server_url: string,
  user_guid: string,
  mode: string
}

const Embedded: React.FC = () => {
  const {
    state: activityState,
    onSaveActivity,
    onResetActivity,
  } = useDeliveryElementContext<OliEmbeddedModelSchema>();

  const [context, setContext] = useState<Context>();

  window.addEventListener("message", (event: MessageEvent) => {
    console.log(event.data);
    if(context) {
      // @ts-ignore
      event.source.postMessage(JSON.stringify({
          authenticationtoken: "none", sessionid: "1958e2f50a0000562295c9a569354ab5",
          resourcetypeid: context.activity_type, superactivityserver: context.server_url,
          activitymode: context.mode, activitycontextguid: activityState.attemptGuid,
          activityguid: activityState.attemptGuid, userguid: context.user_guid, mode: "oli"
        }),
        event.origin);
    }
  }, false);

  useEffect(() => {
    // console.log(JSON.stringify(activityState));
    fetchContext();
  }, []);

  const fetchContext = () => {
    fetch('/jcourse/superactivity/context/'+activityState.attemptGuid, {
      method: 'GET',
    })
      .then((response) => response.json())
      .then((json) => {
        // console.log(json);
        setContext(json);
      })
      .catch((error) => {
        // :TODO: display error somehow
        // return error;
      });
  }

  // @ts-ignore
  window.adjustIframeHeight = (i,f) => {
    document.querySelector(f).style.height = (parseInt(i) + 5) + "px";
  }

  return (
    <>
      <Heading
        title="Embedded Activity"
        subtitle="Embedded Activity subtitle"
        id="embedded"
      />
      {context &&  (
        <iframe id={activityState.attemptGuid} src={context.src_url} width="100%" height="700" frameBorder={0}
                data-authenticationtoken="none" data-sessionid="1958e2f50a0000562295c9a569354ab5"
                data-resourcetypeid={context.activity_type} data-superactivityserver={context.server_url}
                data-activitymode={context.mode} allowFullScreen={true} data-activitycontextguid={activityState.attemptGuid}
            data-activityguid={activityState.attemptGuid} data-userguid={context.user_guid} data-mode="oli" />
      )}
    </>
  );
};

export class OliEmbeddedDelivery extends DeliveryElement<OliEmbeddedModelSchema> {

  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<OliEmbeddedModelSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer);
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <Embedded />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, OliEmbeddedDelivery);