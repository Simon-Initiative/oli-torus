import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { LoadingSpinner } from 'components/common/LoadingSpinner';
import { useLoader } from 'components/hooks/useLoader';
import { LTIExternalToolFrame } from 'components/lti/LTIExternalToolFrame';
import { Alert } from 'components/misc/Alert';
import { activityDeliverySlice } from 'data/activities/DeliveryState';
import { getLtiExternalToolDetails } from 'data/persistence/lti_platform';
import { configureStore } from 'state/store';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import * as ActivityTypes from '../types';
import { LTIExternalToolSchema } from './schema';

const LTIExternalTool: React.FC = () => {
  const { model, state, context } = useDeliveryElementContext<LTIExternalToolSchema>();

  const ltiToolDetailsLoader = useLoader(
    () =>
      state.activityId
        ? getLtiExternalToolDetails('sections', context.sectionSlug, `${state.activityId}`)
        : Promise.resolve(null),
    [state.activityId],
  );

  return ltiToolDetailsLoader.caseOf({
    loading: () => <LoadingSpinner />,
    failure: (error) => <Alert variant="error">{error}</Alert>,
    success: (ltiToolDetails) =>
      ltiToolDetails ? (
        <div className="activity lti-external-tool-activity">
          <div className="activity-content">
            <LTIExternalToolFrame
              mode="delivery"
              name={ltiToolDetails.name}
              launchParams={ltiToolDetails.launch_params}
              resourceId={`${context.resourceId}`}
              openInNewTab={model.openInNewTab}
              height={model.height}
            />
          </div>
        </div>
      ) : (
        <Alert variant="error">Failed to load LTI activity</Alert>
      ),
  });
};

// Defines the web component, a simple wrapper over our React component above
export class LTIExternalToolDelivery extends DeliveryElement<LTIExternalToolSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<LTIExternalToolSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer, {
      name: 'LTIExternalToolDelivery',
    });

    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <LTIExternalTool />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, LTIExternalToolDelivery);
