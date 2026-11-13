import React, { useEffect, useRef, useState } from 'react';
import ReactDOM from 'react-dom';
import { Objective } from 'data/content/objective';
import {
  InteractiveBuildResponse,
  cancelInteractiveBuild,
  getInteractiveBuild,
  startInteractiveBuild,
} from 'data/persistence/interactive';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AgentOutput } from './AgentOutput';
import { InteractiveExperience } from './InteractiveDelivery';
import manifest from './manifest.json';
import { InteractiveModelSchema } from './schema';
import { interactiveSkills } from './utils';

/** Edits the generation inputs for an Interactive, independently of its eventual parts. */
export function Interactive(props: AuthoringElementProps<InteractiveModelSchema>) {
  const { model, editMode, onEdit, authoringContext } = props;
  const objectives: Objective[] = authoringContext?.allObjectives ?? [];
  const skills = interactiveSkills(objectives);
  const [build, setBuild] = useState<InteractiveBuildResponse['build']>(null);
  const [error, setError] = useState<string | null>(null);
  const [launching, setLaunching] = useState(false);
  const [cancelRequested, setCancelRequested] = useState(false);
  const cancelledBuild = useRef<string | null>(null);
  const [pollVersion, setPollVersion] = useState(0);
  const [historySelection, setHistorySelection] = useState('original');
  const [showPreview, setShowPreview] = useState(false);
  const [previewRun, setPreviewRun] = useState(0);
  const revising = !!model.bundle;
  const history = model.authoring.revision_prompts ?? [];
  const propsRef = useRef(props);
  propsRef.current = props;
  const active =
    launching ||
    (!!build && ['queued', 'launching', 'running', 'cancelling'].includes(build.status));
  const canEdit = editMode && !active;
  const observedBuild = useRef<string | null>(null);
  if (active && build) observedBuild.current = build.id;

  useEffect(() => {
    if (!props.activityId || props.mode === 'instructor_preview') return;
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout>;
    const poll = async () => {
      let retry = true;
      try {
        const response = await getInteractiveBuild(props.projectSlug, props.activityId as number);
        if (cancelled) return;
        if (
          response.build?.id === cancelledBuild.current &&
          ['queued', 'launching', 'running'].includes(response.build?.status)
        )
          return;
        setBuild(response.build);
        setError(null);
        if (
          response.activity &&
          response.build?.status === 'completed' &&
          propsRef.current.editMode &&
          propsRef.current.model.bundle?.buildId !== response.build.id
        ) {
          await propsRef.current.onCustomEvent?.('interactiveBuildCompleted', response.activity);
        }
        retry =
          !!response.build &&
          ['queued', 'launching', 'running', 'cancelling'].includes(response.build.status);
      } catch (reason: any) {
        if (!cancelled) setError(reason?.message || 'Unable to read session status. Reconnecting…');
      } finally {
        if (!cancelled && retry) timer = setTimeout(poll, 3000);
      }
    };
    void poll();
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [props.projectSlug, props.activityId, props.mode, pollVersion]);

  const startBuild = async () => {
    if (!props.activityId || !canEdit) return;
    setLaunching(true);
    setBuild(null);
    cancelledBuild.current = null;
    setError(null);
    try {
      const response = await startInteractiveBuild(
        props.projectSlug,
        props.activityId,
        authoringContext?.lockId ?? props.activityId,
        model.authoring,
      );
      setBuild(response.build);
      if (response.activity) {
        await props.onCustomEvent?.('interactiveBuildCompleted', response.activity);
      }
      setPollVersion((version) => version + 1);
    } catch (reason: any) {
      setError(reason?.message || 'Unable to start the build.');
    } finally {
      setLaunching(false);
    }
  };

  const cancelBuild = async () => {
    if (!build || cancelRequested) return;
    setCancelRequested(true);
    setError(null);
    try {
      const response = await cancelInteractiveBuild(
        props.projectSlug,
        props.activityId as number,
        build.id,
      );
      cancelledBuild.current = build.id;
      setBuild(response.build);
      setPollVersion((version) => version + 1);
    } catch (reason: any) {
      setError(reason?.message || 'Unable to confirm cancellation. The session remains visible.');
    } finally {
      setCancelRequested(false);
    }
  };

  const outputPane = (active ||
    (build?.status !== 'cancelled' &&
      (!!build?.transcript || (build && observedBuild.current === build.id)))) && (
    <AgentOutput
      project={props.projectSlug}
      activity={props.activityId as number}
      build={build}
      active={active}
      cancelling={cancelRequested || build?.status === 'cancelling'}
      canCancel={editMode}
      onCancel={() => void cancelBuild()}
      onFinished={() => setPollVersion((version) => version + 1)}
    />
  );

  const update = (changes: Partial<InteractiveModelSchema['authoring']>) =>
    onEdit({ ...model, authoring: { ...model.authoring, ...changes } });

  if (props.mode === 'instructor_preview') {
    return (
      <InteractiveExperience
        model={model}
        preview={{ partIds: model.authoring.parts.map((part) => String(part.id)), readOnly: true }}
      />
    );
  }

  return (
    <div className="flex flex-col gap-6 py-4">
      <fieldset disabled={!canEdit} className="flex flex-col gap-2">
        <legend className="mb-2 text-base font-semibold">Target skills</legend>
        <p className="text-sm text-gray-600 dark:text-gray-300">
          Select the skills learners will practice in this experience.
        </p>
        {skills.length === 0 ? (
          <p className="text-sm text-gray-600 dark:text-gray-300">
            Add sub-objectives to a top-level learning objective in this project to select skills.
          </p>
        ) : (
          <div className="flex max-h-60 flex-col gap-2 overflow-y-auto rounded border border-gray-300 p-3 dark:border-gray-600">
            {skills.map((skill) => (
              <label key={skill.id} className="flex items-start gap-2">
                <input
                  type="checkbox"
                  className="mt-1"
                  checked={model.authoring.selectedSkillIds.includes(skill.id)}
                  onChange={(event) =>
                    update({
                      selectedSkillIds: event.target.checked
                        ? [...model.authoring.selectedSkillIds, skill.id]
                        : model.authoring.selectedSkillIds.filter((id) => id !== skill.id),
                    })
                  }
                />
                <span>{skill.title}</span>
              </label>
            ))}
          </div>
        )}
      </fieldset>
      {revising ? (
        <>
          <label className="flex flex-col gap-2 font-semibold">
            Prompt history
            <select
              value={historySelection}
              onChange={(event) => setHistorySelection(event.target.value)}
              className="rounded border border-gray-300 bg-white p-2 text-gray-900 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100"
            >
              <option value="original">Original prompt</option>
              {history.map((_, index) => (
                <option key={index} value={String(index)}>
                  Revision {index + 1}
                </option>
              ))}
            </select>
          </label>
          <label className="flex flex-col gap-2 font-semibold">
            Saved prompt
            <textarea
              readOnly
              rows={6}
              value={
                historySelection === 'original'
                  ? model.authoring.prompt
                  : history[Number(historySelection)] ?? ''
              }
              className="w-full rounded border border-gray-300 bg-gray-50 p-3 font-normal text-gray-900 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100"
            />
          </label>
          <div className="flex flex-col">
            <label className="flex flex-col gap-2 font-semibold">
              Revision prompt
              <textarea
                rows={active ? 3 : 14}
                disabled={!editMode}
                readOnly={active}
                value={model.authoring.revision_prompt ?? ''}
                placeholder="Describe the changes you want to make..."
                className="w-full rounded border border-gray-300 bg-white p-3 font-normal text-gray-900 disabled:opacity-60 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100"
                onChange={(event) => update({ revision_prompt: event.target.value })}
              />
            </label>
            {outputPane}
          </div>
        </>
      ) : (
        <div className="flex flex-col">
          <label className="flex flex-col gap-2 font-semibold">
            Author prompt
            <textarea
              rows={active ? 3 : 14}
              disabled={!editMode}
              readOnly={active}
              value={model.authoring.prompt}
              placeholder="Describe the learning experience you want to create..."
              className="w-full rounded border border-gray-300 bg-white p-3 font-normal text-gray-900 disabled:opacity-60 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100"
              onChange={(event) =>
                update({ prompt: event.target.value, previewText: event.target.value })
              }
            />
          </label>
          {outputPane}
        </div>
      )}
      <div className="flex flex-wrap gap-4">
        <label className="flex flex-col gap-2 font-semibold">
          Model
          <select
            className="rounded border border-gray-300 bg-white p-2 text-gray-900 dark:bg-gray-800 dark:text-gray-100"
            disabled={!canEdit}
            value={model.authoring.model ?? 'gpt-6-astra'}
            onChange={(event) =>
              update({ model: event.target.value as InteractiveModelSchema['authoring']['model'] })
            }
          >
            <option value="gpt-6-astra">Astra</option>
            <option value="gpt-6-sol">Sol</option>
          </select>
        </label>
        <label className="flex flex-col gap-2 font-semibold">
          Reasoning level
          <select
            className="rounded border border-gray-300 bg-white p-2 text-gray-900 dark:bg-gray-800 dark:text-gray-100"
            disabled={!canEdit}
            value={model.authoring.reasoning ?? 'medium'}
            onChange={(event) =>
              update({
                reasoning: event.target.value as InteractiveModelSchema['authoring']['reasoning'],
              })
            }
          >
            <option value="low">Low</option>
            <option value="medium">Medium</option>
            <option value="high">High</option>
          </select>
        </label>
      </div>
      <div className="flex items-center gap-3">
        <button
          type="button"
          disabled={
            !canEdit ||
            !props.activityId ||
            !(revising ? model.authoring.revision_prompt ?? '' : model.authoring.prompt).trim() ||
            model.authoring.selectedSkillIds.length === 0
          }
          onClick={() => void startBuild()}
          className="rounded bg-primary px-4 py-2 text-white disabled:cursor-not-allowed disabled:opacity-50"
        >
          {active ? (revising ? 'Revising…' : 'Building…') : revising ? 'Revise' : 'Build'}
        </button>
        <span role="status" className="text-sm text-gray-600 dark:text-gray-300">
          {build?.status === 'cancelled'
            ? 'Session cancelled. You can edit your prompt and start again.'
            : build?.status === 'completed'
            ? 'Build complete. The bundle is saved.'
            : active
            ? 'Building and testing your experience. You can return to this page later.'
            : 'Build a static learning experience from your prompt and selected skills.'}
        </span>
      </div>
      {model.bundle && (
        <section className="flex flex-col gap-3" aria-label="Interactive preview">
          <div className="flex items-center gap-3">
            <button
              type="button"
              aria-expanded={showPreview}
              onClick={() => setShowPreview((visible) => !visible)}
              className="rounded border border-gray-300 px-3 py-2 dark:border-gray-600"
            >
              {showPreview ? 'Hide preview' : 'Preview experience'}
            </button>
            {showPreview && (
              <button
                type="button"
                onClick={() => setPreviewRun((run) => run + 1)}
                className="rounded border border-gray-300 px-3 py-2 dark:border-gray-600"
              >
                Restart preview
              </button>
            )}
          </div>
          {showPreview && (
            <>
              <p className="text-sm text-gray-600 dark:text-gray-300">
                Preview progress and scores are temporary and are not saved.
              </p>
              <InteractiveExperience
                key={`${model.bundle.buildId}:${previewRun}`}
                model={model}
                preview={{ partIds: model.authoring.parts.map((part) => String(part.id)) }}
              />
            </>
          )}
        </section>
      )}
      {(error || build?.error) && (
        <p role="alert" className="text-red-600 dark:text-red-300">
          {error || build?.error}
        </p>
      )}
    </div>
  );
}

export class InteractiveAuthoring extends AuthoringElement<InteractiveModelSchema> {
  disconnectedCallback() {
    this.connected = false;
    ReactDOM.unmountComponentAtNode(this.mountPoint);
  }

  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<InteractiveModelSchema>) {
    ReactDOM.render(<Interactive {...props} />, mountPoint);
  }
}

window.customElements.define(manifest.authoring.element, InteractiveAuthoring);
