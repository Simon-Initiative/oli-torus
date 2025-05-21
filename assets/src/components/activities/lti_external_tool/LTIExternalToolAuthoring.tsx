import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { LoadingSpinner } from 'components/common/LoadingSpinner';
import { useLoader } from 'components/hooks/useLoader';
import { LTIExternalToolFrame } from 'components/lti/LTIExternalToolFrame';
import { Alert } from 'components/misc/Alert';
import { getLtiExternalToolDetails } from 'data/persistence/lti_platform';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { AuthoringCheckbox } from '../common/authoring/AuthoringCheckbox';
import * as ActivityTypes from '../types';
import { LTIExternalToolSchema } from './schema';

const store = configureStore();

const LTIExternalTool: React.FC = () => {
  const { model, projectSlug, activityId, onEdit } =
    useAuthoringElementContext<LTIExternalToolSchema>();

  const activityIdStr = activityId ? `${activityId}` : undefined;

  const ltiToolDetailsLoader = useLoader(
    () =>
      activityIdStr
        ? getLtiExternalToolDetails('projects', projectSlug, activityIdStr)
        : Promise.resolve(null),
    [activityIdStr],
  );

  if (activityIdStr == undefined) {
    console.error('LTIExternalTool: activityId is undefined');

    return <Alert variant="error">Failed to load LTI activity</Alert>;
  }

  return ltiToolDetailsLoader.caseOf({
    loading: () => <LoadingSpinner />,
    failure: (error) => <Alert variant="error">{error}</Alert>,
    success: (ltiToolDetails) =>
      ltiToolDetails ? (
        <div className="activity lti-external-tool-activity">
          <div className="activity-content">
            <LTIExternalToolFrame
              mode="authoring"
              name={ltiToolDetails.name}
              launchParams={ltiToolDetails.launch_params}
              resourceId={activityIdStr}
              openInNewTab={model.openInNewTab}
              height={model.height}
              onEditHeight={(height: number | undefined) => onEdit({ ...model, height })}
            />

            <div>
              <AuthoringCheckbox
                label="Launch tool in new window"
                id="launchInNewWindow"
                value={model.openInNewTab}
                onChange={(value) => onEdit({ ...model, openInNewTab: value })}
                editMode={true}
              />
            </div>
            <div className="text-gray-500 my-4">
              Reminder: Editing an external tool may affect published courses.
            </div>
          </div>
        </div>
      ) : (
        <Alert variant="error">Failed to load LTI activity</Alert>
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
