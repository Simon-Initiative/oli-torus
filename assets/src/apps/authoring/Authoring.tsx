import React, { useState } from 'react';

export interface AuthoringProps {
  isAdmin: boolean;
  projectSlug: string;
  revisionSlug: string;
  content: any;
}

export const Authoring: React.FC<AuthoringProps> = (props: AuthoringProps) => {
  const url = `/project/${props.projectSlug}/preview/${props.revisionSlug}`;
  const windowName = `preview-${props.projectSlug}`;
  const [panelState, setPanelState] = useState({ left: true, right: true });

  const PreviewButton = () => (
    <a className="btn btn-sm btn-outline-primary ml-3" onClick={() => window.open(url, windowName)}>
      Preview <i className="las la-external-link-alt ml-1"></i>
    </a>
  );

  return (
    <div className="advanced-authoring">
      <nav className="aa-header-nav">
        header nav
        <PreviewButton />
      </nav>
      <section className={`aa-panel left-panel${panelState.left ? ' open' : ''}`}>
        <p>left sidebar</p>
      </section>
      <section className="aa-stage">
        <h1>Main Content Stage</h1>
        <div className="btn-group" role="group">
          <button
            onClick={() => setPanelState({ ...panelState, left: !panelState.left })}
            type="button"
            className="btn btn-secondary"
          >
            toggle left
          </button>
          <button
            onClick={() => setPanelState({ ...panelState, right: !panelState.right })}
            type="button"
            className="btn btn-secondary"
          >
            toggle right
          </button>
        </div>
        <div>{JSON.stringify(props.content)}</div>
      </section>
      <section className={`aa-panel right-panel${panelState.right ? ' open' : ''}`}>
        <p>right sidebar</p>
      </section>
    </div>
  );
};
