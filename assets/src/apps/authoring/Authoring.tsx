import React, { useEffect, useState } from 'react';
import HeaderNav from './HeaderNav';

export interface AuthoringProps {
  isAdmin: boolean;
  projectSlug: string;
  revisionSlug: string;
  content: any;
}

export const Authoring: React.FC<AuthoringProps> = (props: AuthoringProps) => {
  const url = `/project/${props.projectSlug}/preview/${props.revisionSlug}`;
  const windowName = `preview-${props.projectSlug}`;
  const [panelState, setPanelState] = useState({ left: true, right: true, top: true });

  const PreviewButton = () => (
    <a className="btn btn-sm btn-outline-primary" onClick={() => window.open(url, windowName)}>
      Preview <i className="las la-external-link-alt ml-1"></i>
    </a>
  );

  // Prevents double scroll bars
  useEffect(() => {
    document.body.classList.add('overflow-hidden');
    return () => {
      document.body.classList.remove('overflow-hidden');
    };
  }, []);

  return (
    <div className="advanced-authoring">
      <HeaderNav content={props.content} isVisible={panelState.top} />
      <section className={`aa-panel left-panel${panelState.left ? ' open' : ''}`}>
        <p>left sidebar</p>
      </section>
      <section className="aa-stage">
        <div className="aa-stage-inner">
          <PreviewButton />
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
            <button
              onClick={() =>
                setPanelState({
                  right: !panelState.right,
                  left: !panelState.left,
                  top: !panelState.top,
                })
              }
              type="button"
              className="btn btn-secondary"
            >
              toggle all
            </button>
          </div>
        </div>
        {/* <div>{JSON.stringify(props.content)}</div> */}
      </section>
      <section className={`aa-panel right-panel${panelState.right ? ' open' : ''}`}>
        <p>right sidebar</p>
      </section>
    </div>
  );
};
