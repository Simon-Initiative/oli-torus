import React, { useEffect, useState } from 'react';
import Accordion from './Accordion/Accordion';
import HeaderNav from './HeaderNav';
import { SidePanel } from './SidePanel';
import TabStrip from './TabStrip/TabStrip';

export interface AuthoringProps {
  isAdmin: boolean;
  projectSlug: string;
  revisionSlug: string;
  content: any;
}

export const Authoring: React.FC<AuthoringProps> = (props: AuthoringProps) => {
  const url = `/authoring/project/${props.projectSlug}/preview/${props.revisionSlug}`;
  const windowName = `preview-${props.projectSlug}`;
  const authoringContainer = document.getElementById('advanced-authoring');
  const [appState, setAppState] = useState<any>({ isVisible: false });
  const [panelState, setPanelState] = useState({ left: true, right: true, top: true });
  const leftPanelData = {
    tabs: [
      {
        id: 1,
        title: 'Sequence',
        data: ['Intro Screen',
          'Pick your character',
          'Choose your title']
      },
      {
        id: 2,
        title: 'Adaptivity',
        data: ['Initial Satee',
          'Default Response']
      }
    ],
  };
  const rightPanelData = {
    tabs: [
      {
        id: 1,
        title: 'Lesson',
        data: 'Lesson Data',
      },
      {
        id: 2,
        title: 'Screen',
        data: 'Screen Data',
      },
      {
        id: 3,
        title: 'Component',
        data: 'Component Data',
      },
    ],
  };
  const PreviewButton = () => (
    <a className="btn btn-sm btn-outline-primary" onClick={() => window.open(url, windowName)}>
      Preview <i className="las la-external-link-alt ml-1"></i>
    </a>
  );

  useEffect(() => {
    if (appState.isVisible) {
      document.body.classList.add('overflow-hidden'); // prevents double scroll bars
      authoringContainer?.classList.remove('d-none');
      setTimeout(() => {
        authoringContainer?.classList.add('startup');
      }, 50);
    }
    if (!appState.isVisible) {
      document.body.classList.remove('overflow-hidden');
      authoringContainer?.classList.remove('startup');
      setTimeout(() => {
        authoringContainer?.classList.add('d-none');
      }, 350);
    }
    return () => {
      document.body.classList.remove('overflow-hidden');
    };
  }, [appState.isVisible]);

  return (
    <>
      {!appState.isVisible && (
        <button
          onClick={() => setAppState({ ...appState, isVisible: true })}
          type="button"
          className="btn btn-primary"
        >
          🚀 Launch
        </button>
      )}
      <div id="advanced-authoring" className={`advanced-authoring d-none`}>
        <HeaderNav content={props.content} isVisible={panelState.top} />
        <SidePanel
          position="left"
          panelState={panelState}
          setPanelState={() => setPanelState({ ...panelState, left: !panelState.left })}
        >
          I am the left side panel.
        <Accordion tabsData={leftPanelData} data={props.content}></Accordion>
        </SidePanel>
        <section className="aa-stage">
          <div className="aa-stage-inner">
            <PreviewButton />
            <h1>Main Content Stage</h1>
            <div className="btn-group" role="group">
              <button
                onClick={() =>
                  setPanelState({
                    right: false,
                    left: false,
                    top: false,
                  })
                }
                type="button"
                className="btn btn-secondary"
              >
                hide all
              </button>
              <button
                onClick={() =>
                  setPanelState({
                    right: true,
                    left: true,
                    top: true,
                  })
                }
                type="button"
                className="btn btn-secondary"
              >
                show all
              </button>
              <button
                onClick={() => setAppState({ ...appState, isVisible: false })}
                type="button"
                className="btn btn-secondary"
              >
                quit
              </button>
            </div>
          </div>
          {/* <div>{JSON.stringify(props.content)}</div> */}
        </section>
        <SidePanel
          position="right"
          panelState={panelState}
          setPanelState={() => setPanelState({ ...panelState, right: !panelState.right })}
        >
          I am the right side panel.
        <TabStrip tabsData={rightPanelData} data={props.content}></TabStrip>
        </SidePanel>
      </div>
    </>
  );
};
