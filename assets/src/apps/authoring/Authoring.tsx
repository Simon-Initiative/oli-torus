import React, { useEffect } from 'react';
import { Provider, useDispatch, useSelector } from 'react-redux';
import Accordion from './components/Accordion/Accordion';
import EditingCanvas from './components/EditingCanvas/EditingCanvas';
import HeaderNav from './components/HeaderNav';
import { SidePanel } from './components/SidePanel';
import TabStrip from './components/TabStrip/TabStrip';
import store from './store';
import {
  selectLeftPanel,
  selectRightPanel,
  selectTopPanel,
  selectVisible,
  setInitialConfig,
  setPanelState,
  setVisible,
} from './store/app/slice';
import { initializeFromContext } from './store/page/actions/initializeFromContext';
import { PageContext } from './types';

export interface AuthoringProps {
  isAdmin: boolean;
  projectSlug: string;
  revisionSlug: string;
  content: PageContext;
  activityTypes?: any[];
  resourceId?: number;
  paths: Record<string, string>;
}

const Authoring: React.FC<AuthoringProps> = (props: AuthoringProps) => {
  const dispatch = useDispatch();

  const authoringContainer = document.getElementById('advanced-authoring');
  const isAppVisible = useSelector(selectVisible);

  const leftPanelState = useSelector(selectLeftPanel);
  const rightPanelState = useSelector(selectRightPanel);
  const topPanelState = useSelector(selectTopPanel);
  const panelState = { left: leftPanelState, right: rightPanelState, top: topPanelState };

  const handlePanelStateChange = ({
    top,
    right,
    left,
  }: {
    top?: boolean;
    right?: boolean;
    left?: boolean;
  }) => {
    dispatch(setPanelState({ top, right, left }));
  };

  useEffect(() => {
    const appConfig = {
      paths: props.paths,
      isAdmin: props.isAdmin,
      projectSlug: props.projectSlug,
      revisionSlug: props.revisionSlug,
    };
    dispatch(setInitialConfig(appConfig));

    if (props.content) {
      dispatch(initializeFromContext(props.content));
    }
  }, [props]);

  const leftPanelData = {
    tabs: [
      {
        id: 1,
        title: 'Sequence',
        data: ['Intro Screen', 'Pick your character', 'Choose your title'],
      },
      {
        id: 2,
        title: 'Adaptivity',
        data: ['Initial Satee', 'Default Response'],
      },
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

  useEffect(() => {
    if (isAppVisible) {
      document.body.classList.add('overflow-hidden'); // prevents double scroll bars
      authoringContainer?.classList.remove('d-none');
      setTimeout(() => {
        authoringContainer?.classList.add('startup');
      }, 50);
    }
    if (!isAppVisible) {
      document.body.classList.remove('overflow-hidden');
      authoringContainer?.classList.remove('startup');
      setTimeout(() => {
        authoringContainer?.classList.add('d-none');
      }, 350);
    }
    return () => {
      document.body.classList.remove('overflow-hidden');
    };
  }, [isAppVisible]);

  return (
    <>
      {!isAppVisible && (
        <button
          onClick={() => dispatch(setVisible({ visible: true }))}
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
          onToggle={() => handlePanelStateChange({ left: !panelState.left })}
        >
          <Accordion tabsData={leftPanelData} data={props.content}></Accordion>
        </SidePanel>
        <EditingCanvas />
        <SidePanel
          position="right"
          panelState={panelState}
          onToggle={() => handlePanelStateChange({ right: !panelState.right })}
        >
          <TabStrip tabsData={rightPanelData} data={props.content}></TabStrip>
        </SidePanel>
      </div>
    </>
  );
};

const ReduxApp: React.FC<AuthoringProps> = (props) => (
  <Provider store={store}>
    <Authoring {...props} />
  </Provider>
);

export default ReduxApp;
