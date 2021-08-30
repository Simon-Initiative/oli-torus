import {configureStore} from "state/store";
import React, {useEffect} from "react";
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
import {activityDeliverySlice, initializeState} from "data/content/activities/DeliveryState";

const Embedded: React.FC = () => {
  const {
    state: activityState,
    onSaveActivity,
    onResetActivity,
  } = useDeliveryElementContext<OliEmbeddedModelSchema>();

  useEffect(() => {
    console.log(JSON.stringify(activityState));
  }, []);

  return (
    <>
      <Heading
        title="Embedded Activity"
        subtitle="Embedded Activity subtitle"
        id="embedded"
      />
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