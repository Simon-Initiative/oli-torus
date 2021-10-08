import React, { useEffect, useState } from 'react';
import { Alert, Button } from 'react-bootstrap';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { BottomPanel } from './BottomPanel';
import { AdaptivityEditor } from './components/AdaptivityEditor/AdaptivityEditor';
import { InitStateEditor } from './components/AdaptivityEditor/InitStateEditor';
import EditingCanvas from './components/EditingCanvas/EditingCanvas';
import HeaderNav from './components/HeaderNav';
import LeftMenu from './components/LeftMenu/LeftMenu';
import RightMenu from './components/RightMenu/RightMenu';
import { SidePanel } from './components/SidePanel';
import store from './store';
import { acquireEditingLock, releaseEditingLock } from './store/app/actions/locking';
import {
  selectBottomPanel,
  selectCurrentRule,
  selectHasEditingLock,
  selectLeftPanel,
  selectProjectSlug,
  selectRevisionSlug,
  selectRightPanel,
  selectshowEditingLockErrMsg,
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
  const requestEditLock = async () => await dispatch(acquireEditingLock());

  const authoringContainer = document.getElementById('advanced-authoring');
  const [isAppVisible, setIsAppVisible] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  const hasEditingLock = useSelector(selectHasEditingLock);
  const showEditingLockErrMsg = useSelector(selectshowEditingLockErrMsg);
  const projectSlug = useSelector(selectProjectSlug);
  const revisionSlug = useSelector(selectRevisionSlug);
  const currentRule = useSelector(selectCurrentRule);
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

  const url = `/authoring/project/${projectSlug}/preview/${revisionSlug}`;
  const windowName = `preview-${projectSlug}`;

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
      dispatch(initializeFromContext({ context: props.content, config: appConfig }));
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
    if (!isAppVisible || !hasEditingLock) {
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
  }, [isAppVisible, hasEditingLock]);

  useEffect(() => {
    window.addEventListener('beforeunload', async () => await dispatch(releaseEditingLock()));
    setTimeout(() => {
      if (hasEditingLock) {
        setIsAppVisible(true);
      }
    }, 500);
    setTimeout(() => {
      setIsLoading(false);
    }, 2000);

    return () => {
      window.removeEventListener('beforeunload', async () => await dispatch(releaseEditingLock()));
    };
  }, [hasEditingLock]);

  useEffect(() => {
    requestEditLock();
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
      {hasEditingLock && (
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
            {currentRule === 'initState' && <InitStateEditor />}
            {currentRule !== 'initState' && <AdaptivityEditor />}
          </BottomPanel>
          <SidePanel
            position="right"
            panelState={panelState}
            onToggle={() => handlePanelStateChange({ right: !panelState.right })}
          >
            <RightMenu />
          </SidePanel>
        </div>
      )}
      {!hasEditingLock && (
        <Alert variant="warning">
          <Alert.Heading>
            {showEditingLockErrMsg ? 'Editing Session Timed Out' : 'Editing In Progress'}
          </Alert.Heading>
          <p>
            {showEditingLockErrMsg
              ? `Too much time passed since your last edit and now someone else is currently editing this page. `
              : `Sorry, someone else is currently editing this page. `}
            You can try refreshing the browser to see if the current editor is done, or you can use
            the link below to open a preview of the page.
          </p>
          <hr />
          <Button
            variant="outline-warning"
            className="text-dark"
            onClick={() => window.open(url, windowName)}
          >
            Open Preview <i className="las la-external-link-alt ml-1"></i>
          </Button>
        </Alert>
      )}
    </>
  );
};

const ReduxApp: React.FC<AuthoringProps> = (props) => (
  <Provider store={store}>
    <Authoring {...props} />
  </Provider>
);

export default ReduxApp;
