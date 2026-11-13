import React, { useEffect, useRef, useState } from 'react';
import { InteractiveBuildResponse } from 'data/persistence/interactive';

type Build = NonNullable<InteractiveBuildResponse['build']>;

/** A reconnecting, selectable output pane; closing it never stops the hosted build. */
export function AgentOutput({
  project,
  activity,
  build,
  active,
  cancelling,
  canCancel,
  onCancel,
  onFinished,
}: {
  project: string;
  activity: number;
  build: Build | null;
  active: boolean;
  cancelling: boolean;
  canCancel: boolean;
  onCancel: () => void;
  onFinished: () => void;
}) {
  const [output, setOutput] = useState(build?.transcript ?? '');
  const [connection, setConnection] = useState('Connecting…');
  const terminal = useRef<HTMLTextAreaElement>(null);
  const follow = useRef(true);
  const previousBuild = useRef(build?.id);
  const finished = useRef(onFinished);
  finished.current = onFinished;

  useEffect(() => {
    if (previousBuild.current !== build?.id) {
      setOutput(build?.transcript ?? '');
      follow.current = true;
    } else if (build?.transcript) setOutput(build.transcript);
    previousBuild.current = build?.id;
    if (!build || !['queued', 'launching', 'running', 'cancelling'].includes(build.status)) {
      setConnection(build?.status === 'completed' ? 'Complete' : 'Stopped');
      return;
    }
    setConnection('Connecting…');
    // Phoenix's API pipeline negotiates JSON; the action switches to SSE after authorization.
    const source = new EventSource(
      `/api/v1/interactives/${encodeURIComponent(project)}/${activity}/builds/${encodeURIComponent(
        build.id,
      )}/events?_format=json`,
    );
    source.onopen = () => setConnection('Live');
    source.onerror = () => setConnection('Reconnecting…');
    source.addEventListener('output', (event) => {
      const data = JSON.parse((event as MessageEvent).data);
      if (typeof data.text === 'string')
        setOutput((previous) => (data.restoring ? previous || data.text : data.text));
    });
    source.addEventListener('done', () => {
      source.close();
      setConnection('Finished');
      finished.current();
    });
    return () => source.close();
  }, [project, activity, build?.id, build?.status]);

  useEffect(() => {
    if (follow.current && terminal.current)
      terminal.current.scrollTop = terminal.current.scrollHeight;
  }, [output]);

  return (
    <section
      aria-label="Agent session"
      className="overflow-hidden rounded-b border border-gray-700 bg-black text-white"
    >
      <div className="flex items-center justify-between gap-3 border-b border-gray-700 px-3 py-2">
        <span className="text-sm font-semibold">Agent output</span>
        <span role="status" className="ml-auto text-xs text-gray-300">
          {cancelling
            ? 'Stopping session…'
            : active
            ? connection
            : build?.status === 'completed'
            ? 'Complete'
            : 'Stopped'}
        </span>
        {active && (
          <button
            type="button"
            disabled={!canCancel || cancelling || !build}
            onClick={onCancel}
            className="rounded border border-gray-500 px-3 py-1 text-sm text-white hover:bg-gray-800 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {cancelling ? 'Cancelling…' : 'Cancel session'}
          </button>
        )}
      </div>
      <textarea
        ref={terminal}
        aria-label="Agent output"
        readOnly
        rows={14}
        spellCheck={false}
        value={output || 'Preparing the agent session…'}
        onScroll={() => {
          const field = terminal.current;
          if (field)
            follow.current = field.scrollTop + field.clientHeight >= field.scrollHeight - 24;
        }}
        className="block w-full resize-none border-0 bg-black p-3 font-mono text-sm leading-5 text-white focus:outline-none focus:ring-2 focus:ring-primary"
      />
    </section>
  );
}
