import React, { useEffect, useState } from 'react';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { BottomPanel } from './BottomPanel';
import { AdaptivityEditor } from './components/AdaptivityEditor/AdaptivityEditor';
import EditingCanvas from './components/EditingCanvas/EditingCanvas';
import HeaderNav from './components/HeaderNav';
import LeftMenu from './components/LeftMenu/LeftMenu';
import RightMenu from './components/RightMenu/RightMenu';
import { SidePanel } from './components/SidePanel';
import store from './store';
import {
  selectBottomPanel,
  selectLeftPanel,
  selectRightPanel,
  selectTopPanel,
  setInitialConfig,
  setPanelState,
} from './store/app/slice';
import { initializeFromContext } from './store/page/actions/initializeFromContext';
import { PageContext } from './types';

export interface AuthoringProps {
  isAdmin: boolean;
  projectSlug: string;
  revisionSlug: string;
  content: PageContext;
  activityTypes?: any[];
  partComponentTypes?: any[];
  resourceId?: number;
  paths: Record<string, string>;
}

const Authoring: React.FC<AuthoringProps> = (props: AuthoringProps) => {
  const dispatch = useDispatch();

  const authoringContainer = document.getElementById('advanced-authoring');
  const [isAppVisible, setIsAppVisible] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  const leftPanelState = useSelector(selectLeftPanel);
  const rightPanelState = useSelector(selectRightPanel);
  const topPanelState = useSelector(selectTopPanel);
  const bottomPanelState = useSelector(selectBottomPanel);
  const panelState = {
    left: leftPanelState,
    right: rightPanelState,
    top: topPanelState,
    bottom: bottomPanelState,
  };
  const handlePanelStateChange = ({
    top,
    right,
    left,
    bottom,
  }: {
    top?: boolean;
    right?: boolean;
    left?: boolean;
    bottom?: boolean;
  }) => {
    dispatch(setPanelState({ top, right, left, bottom }));
  };

  useEffect(() => {
    const appConfig = {
      paths: props.paths,
      isAdmin: props.isAdmin,
      projectSlug: props.projectSlug,
      revisionSlug: props.revisionSlug,
      partComponentTypes: props.partComponentTypes,
      activityTypes: props.activityTypes,
    };
    dispatch(setInitialConfig(appConfig));

    if (props.content) {
      dispatch(initializeFromContext(props.content));
    }
  }, [props]);

  useEffect(() => {
    if (isAppVisible) {
      // forced light mode to save on initial dev time
      const darkModeCss: any = document.getElementById('authoring-theme-dark');
      darkModeCss.href = '/css/authoring_torus_light.css';
      document.body.classList.add('overflow-hidden'); // prevents double scroll bars
      authoringContainer?.classList.remove('d-none');
      setTimeout(() => {
        authoringContainer?.classList.add('startup');
      }, 50);
    }
    if (!isAppVisible) {
      // reset forced light mode
      const darkModeCss: any = document.getElementById('authoring-theme-dark');
      darkModeCss.href = '/css/authoring_torus_dark.css';
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

  useEffect(() => {
    setTimeout(() => {
      setIsAppVisible(true);
    }, 500);
    setTimeout(() => {
      setIsLoading(false);
    }, 2000);
  }, []);

  return (
    <>
      {isLoading && (
        <div id="aa-loading">
          <div className="loader spinner-border text-primary" role="status">
            <span className="sr-only">Loading...</span>
          </div>
        </div>
      )}
      <div id="advanced-authoring" className={`advanced-authoring d-none`}>
        <HeaderNav panelState={panelState} isVisible={panelState.top} />
        <SidePanel
          position="left"
          panelState={panelState}
          onToggle={() => handlePanelStateChange({ left: !panelState.left })}
        >
          <LeftMenu />
        </SidePanel>
        <EditingCanvas />
        <BottomPanel
          panelState={panelState}
          onToggle={() => handlePanelStateChange({ bottom: !panelState.bottom })}
        >
          <AdaptivityEditor />
        </BottomPanel>
        <SidePanel
          position="right"
          panelState={panelState}
          onToggle={() => handlePanelStateChange({ right: !panelState.right })}
        >
          <RightMenu />
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
