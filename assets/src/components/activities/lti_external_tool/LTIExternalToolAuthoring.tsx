import React, { useRef, useState } from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { LoadingSpinner } from 'components/common/LoadingSpinner';
import { useLoader } from 'components/hooks/useLoader';
import { LTIExternalToolFrame } from 'components/lti/LTIExternalToolFrame';
import { Alert } from 'components/misc/Alert';
import { Modal, ModalSize } from 'components/modal/Modal';
import {
  LTIExternalToolDetails,
  getAuthoringDeepLinkResult,
  getLtiExternalToolDetails,
} from 'data/persistence/lti_platform';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { AuthoringCheckbox } from '../common/authoring/AuthoringCheckbox';
import * as ActivityTypes from '../types';
import { LTIExternalToolSchema } from './schema';

const store = configureStore();

const LTIExternalTool: React.FC = () => {
  const {
    model,
    editMode,
    mode,
    projectSlug,
    authoringContext,
    activityId,
    onEdit,
    onCustomEvent,
  } = useAuthoringElementContext<LTIExternalToolSchema>();
  const isInstructorPreview = mode === 'instructor_preview';
  const [role, setRole] = useState<'developer' | 'instructor'>('developer');
  const [launchType, setLaunchType] = useState<'regular' | 'deep_link'>('regular');
  const [launch, setLaunch] = useState<LTIExternalToolDetails | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const handlingReturn = useRef(false);
  const activeRequest = useRef<string | undefined>();

  const saveInEditor = async (selection?: LTIExternalToolSchema['deepLink']) => {
    if (!onCustomEvent) throw new Error('Open this activity in the page editor to configure it.');
    let timeout: ReturnType<typeof setTimeout> | undefined;
    try {
      await Promise.race([
        onCustomEvent('ltiAuthoringSave', { selection }).then((result) => {
          if (result !== true)
            throw new Error('Open this activity in the page editor to configure it.');
        }),
        new Promise((_, reject) => {
          timeout = setTimeout(
            () =>
              reject(
                new Error('The editor did not finish saving. Please reload before trying again.'),
              ),
            30000,
          );
        }),
      ]);
    } finally {
      clearTimeout(timeout);
    }
  };

  const startLaunch = async () => {
    setBusy(true);
    setError(null);
    setSaved(false);
    try {
      await saveInEditor();
      const details = await getLtiExternalToolDetails('projects', projectSlug, String(activityId), {
        role,
        launch_type: launchType,
      });
      activeRequest.current = details.request_id;
      handlingReturn.current = false;
      setLaunch(details);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unable to launch the tool.');
    } finally {
      setBusy(false);
    }
  };

  const receiveSelection = async (result: {
    token?: string;
    request_id?: string;
    error?: string;
  }) => {
    if (handlingReturn.current) return;
    if (result.error) {
      setError(result.error);
      return;
    }
    if (!result.token || result.request_id !== activeRequest.current) return;
    handlingReturn.current = true;
    setBusy(true);
    try {
      const validated = await getAuthoringDeepLinkResult(
        projectSlug,
        String(activityId),
        result.token,
      );
      if (validated.request_id !== activeRequest.current)
        throw new Error('This selection belongs to an older launch.');
      await saveInEditor(validated.selection);
      setLaunch(null);
      setSaved(true);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unable to save the tool selection.');
      handlingReturn.current = false;
    } finally {
      setBusy(false);
    }
  };

  const activityIdStr = activityId ? `${activityId}` : undefined;

  const projectsOrSections =
    authoringContext?.previewMode === 'instructor' ? 'sections' : 'projects';

  const ltiToolDetailsLoader = useLoader(
    () =>
      activityIdStr
        ? getLtiExternalToolDetails(projectsOrSections, projectSlug, activityIdStr)
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
            {isInstructorPreview ? (
              <LTIExternalToolFrame
                mode="authoring"
                name={ltiToolDetails.name}
                launchParams={ltiToolDetails.launch_params}
                status={ltiToolDetails.status}
                resourceId={activityIdStr}
                openInNewTab={model.openInNewTab}
                height={model.height}
              />
            ) : (
              <>
                <fieldset
                  disabled={!editMode || busy || launch !== null}
                  className="flex flex-wrap items-end gap-4"
                >
                  <label className="flex flex-col gap-1">
                    Launch as
                    <select
                      className="rounded border p-2"
                      value={role}
                      onChange={(event) => setRole(event.target.value as typeof role)}
                    >
                      <option value="developer">Developer</option>
                      <option value="instructor">Instructor</option>
                    </select>
                  </label>
                  <label className="flex flex-col gap-1">
                    Launch type
                    <select
                      className="rounded border p-2"
                      value={launchType}
                      onChange={(event) => setLaunchType(event.target.value as typeof launchType)}
                    >
                      <option value="regular">Regular</option>
                      {ltiToolDetails.deep_linking_enabled && (
                        <option value="deep_link">Deep Link</option>
                      )}
                    </select>
                  </label>
                  <button
                    type="button"
                    className="rounded border px-4 py-2 font-semibold"
                    onClick={startLaunch}
                  >
                    {launchType === 'regular'
                      ? 'Launch Tool'
                      : model.deepLink
                      ? 'Change Selection from Tool'
                      : 'Select Resource'}
                  </button>
                </fieldset>
                {model.deepLink && (
                  <p className="mt-2">Selection: {model.deepLink.title || 'Selected resource'}</p>
                )}
                {saved && (
                  <p role="status" className="mt-2">
                    Selection saved.
                  </p>
                )}
                {error && <Alert variant="error">{error}</Alert>}
                {launch && (
                  <Modal
                    title={launchType === 'deep_link' ? 'Select Resource from Tool' : launch.name}
                    size={ModalSize.X_LARGE}
                    hideOkButton
                    cancelLabel="Close"
                    keyboard={false}
                    backdrop="static"
                    hideDialogCloseButton={busy}
                    onCancel={() => {
                      if (!handlingReturn.current) {
                        activeRequest.current = undefined;
                        setLaunch(null);
                      }
                    }}
                  >
                    {busy && <p role="status">Saving selection…</p>}
                    {error && <Alert variant="error">{error}</Alert>}
                    <LTIExternalToolFrame
                      key={launch.request_id}
                      mode="delivery"
                      name={launch.name}
                      launchParams={launch.launch_params}
                      status={launch.status}
                      resourceId={`${activityIdStr}-authoring`}
                      openInNewTab={launchType === 'regular' && model.openInNewTab}
                      height={model.height}
                      onEditHeight={
                        launchType === 'regular' && editMode
                          ? (height) => onEdit({ ...model, height })
                          : undefined
                      }
                      onAuthoringDeepLinkComplete={receiveSelection}
                    />
                  </Modal>
                )}
              </>
            )}

            <div>
              <AuthoringCheckbox
                label="Launch tool in new window"
                id={`open-in-new-tab-${activityIdStr}`}
                value={model.openInNewTab}
                onChange={(value) => onEdit({ ...model, openInNewTab: value })}
                editMode={editMode && !isInstructorPreview && !busy && !launch}
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
