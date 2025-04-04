import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Maybe } from 'tsmonad';
import { LoadingSpinner } from 'components/common/LoadingSpinner';
import { useLoader } from 'components/hooks/useLoader';
import { LTIExternalToolFrame } from 'components/lti/LTIExternalToolFrame';
import { Alert } from 'components/misc/Alert';
import { getLtiExternalToolDetails } from 'data/persistence/lti_platform';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import * as ActivityTypes from '../types';
import { LTIExternalToolSchema } from './schema';

const store = configureStore();

const LTIExternalTool: React.FC = () => {
  const { model } = useAuthoringElementContext<LTIExternalToolSchema>();

  const ltiToolDetailsLoader = useLoader(
    () => (model.clientId ? getLtiExternalToolDetails(model.clientId) : Promise.resolve(null)),
    [model.clientId],
  );

  const resourceId = model.id as string;

  return ltiToolDetailsLoader.caseOf({
    loading: () => <LoadingSpinner />,
    failure: (error) => <Alert variant="error">{error}</Alert>,
    success: (ltiToolDetails) =>
      ltiToolDetails ? (
        <div className="activity lti-external-tool-activity">
          <div className="activity-content">
            <LTIExternalToolFrame
              launchParams={ltiToolDetails.launch_params}
              resourceId={resourceId}
            />
          </div>
        </div>
      ) : (
        <Alert variant="error">No client_id set</Alert>
      ),
  });
};

export class LTIExternalToolAuthoring extends AuthoringElement<LTIExternalToolSchema> {
  migrateModelVersion(model: any): LTIExternalToolSchema {
    return model;
  }

  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<LTIExternalToolSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <LTIExternalTool />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, LTIExternalToolAuthoring);
