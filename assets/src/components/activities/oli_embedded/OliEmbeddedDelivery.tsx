import {configureStore} from "state/store";
import React, {useEffect, useState} from "react";
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

interface Context {
  attempt_guid: string,
  src_url: string,
  activity_type: string,
  server_url: string,
  user_guid: string,
  mode: string,
  part_ids: string,
}

const EmbeddedDelivery = (props: DeliveryElementProps<OliEmbeddedModelSchema>) => {
  const {
    state: activityState,
  } = useDeliveryElementContext<OliEmbeddedModelSchema>();


  const [context, setContext] = useState<Context>();
  const [preview, setPreview] = useState<boolean>(false);

  useEffect(() => {
    fetchContext();
  }, []);

  const fetchContext = () => {
    fetch('/jcourse/superactivity/context/'+activityState.attemptGuid, {
      method: 'GET',
    })
      .then((response) => response.json())
      .then((json) => {
        setContext(json);
      })
      .catch((error) => {
        // :TODO: display error somehow
        setPreview(true);
      });
  }

  // @ts-ignore
  window.adjustIframeHeight = (i,f) => {
    const iframe = document.querySelector(f);
    iframe.style.height = (parseInt(i) + 10) + "px";
    iframe.contentWindow.document.querySelector("html").style.height = (parseInt(i) + 10) + "px";
  }

  return (
    <>
      {context && (
        <iframe id={activityState.attemptGuid} src={context.src_url} width="100%" height="700" frameBorder={0}
                data-authenticationtoken="none" data-sessionid="1958e2f50a0000562295c9a569354ab5"
                data-resourcetypeid={context.activity_type} data-superactivityserver={context.server_url}
                data-activitymode={context.mode} allowFullScreen={true} data-activitycontextguid={activityState.attemptGuid}
                data-activityguid={activityState.attemptGuid} data-userguid={context.user_guid} data-partids={context.part_ids} data-mode="oli" />
        )
      }
      {preview && (
        <h4>OLI Embedded does not support preview yet</h4>
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
          <EmbeddedDelivery {...props}/>
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, OliEmbeddedDelivery);