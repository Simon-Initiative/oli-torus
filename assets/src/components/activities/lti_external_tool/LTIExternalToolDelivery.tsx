import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { LoadingSpinner } from 'components/common/LoadingSpinner';
import { useLoader } from 'components/hooks/useLoader';
import { LTIExternalToolFrame } from 'components/lti/LTIExternalToolFrame';
import { Alert } from 'components/misc/Alert';
import { Checkmark } from 'components/misc/icons/Checkmark';
import { Cross } from 'components/misc/icons/Cross';
import { activityDeliverySlice } from 'data/activities/DeliveryState';
import { isCorrect } from 'data/activities/utils';
import { getLtiExternalToolDetails } from 'data/persistence/lti_platform';
import { configureStore } from 'state/store';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { GradedPoints } from '../common/delivery/graded_points/GradedPoints';
import * as ActivityTypes from '../types';
import { LTIExternalToolSchema } from './schema';

const LTIExternalTool: React.FC = () => {
  const { model, state, context, mode } = useDeliveryElementContext<LTIExternalToolSchema>();

  const ltiToolDetailsLoader = useLoader(() => {
    if (!state.activityId) {
      return Promise.resolve(null);
    }

    if (mode === 'author_preview') {
      return getLtiExternalToolDetails('projects', context.projectSlug, `${context.resourceId}`);
    } else {
      return getLtiExternalToolDetails('sections', context.sectionSlug, `${state.activityId}`);
    }
  }, [state.activityId]);

  const isEvaluated = state.score !== null;

  const maybeGradedPoints = (
    <GradedPoints
      shouldShow={
        isEvaluated &&
        context.graded &&
        mode === 'review' &&
        context.showFeedback === true &&
        context.surveyId === null
      }
      icon={isCorrect(state) ? <Checkmark /> : <Cross />}
      attemptState={state}
    />
  );

  return ltiToolDetailsLoader.caseOf({
    loading: () => <LoadingSpinner />,
    failure: (error) => <Alert variant="error">{error}</Alert>,
    success: (ltiToolDetails) => {
      if (!ltiToolDetails) {
        return <Alert variant="error">Failed to load LTI activity</Alert>;
      }

      if (mode === 'author_preview') {
        return (
          <button className="flex flex-row w-full justify-between shadow-lg px-4 py-3 mb-4 bg-white rounded-lg border-2 border-gray-100 text-left text-primary font-semibold hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2">
            {ltiToolDetails.name}
            <div className="relative group">
              <div className="p-1 rounded-lg flex justify-center items-center overflow-hidden">
                <i className="fa-solid fa-triangle-exclamation text-amber-400"></i>
              </div>
              <div className="absolute left-1/2 -translate-x-1/2 -top-12 w-52 px-1 py-2 bg-white border rounded shadow-lg hidden group-hover:block z-10 self-stretch text-center justify-center text-xs font-bold leading-none text-black">
                You cannot interact with this tool in the authoring preview.
              </div>
            </div>
          </button>
        );
      }

      return (
        <div className="activity lti-external-tool-activity">
          <div className="activity-content">
            {maybeGradedPoints}
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
      );
    },
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
