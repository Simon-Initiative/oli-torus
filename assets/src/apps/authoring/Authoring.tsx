import React, { useEffect, useState } from 'react';
import { Alert, Button } from 'react-bootstrap';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { isFirefox } from 'utils/browser';
import { BottomPanel } from './BottomPanel';
import { AdaptivityEditor } from './components/AdaptivityEditor/AdaptivityEditor';
import { InitStateEditor } from './components/AdaptivityEditor/InitStateEditor';
import EditingCanvas from './components/EditingCanvas/EditingCanvas';
import HeaderNav from './components/HeaderNav';
import LeftMenu from './components/LeftMenu/LeftMenu';
import DiagnosticsWindow from './components/Modal/DiagnosticsWindow';
import ScoringOverview from './components/Modal/ScoringOverview';
import RightMenu from './components/RightMenu/RightMenu';
import { SidePanel } from './components/SidePanel';
import store from './store';
import { releaseEditingLock } from './store/app/actions/locking';
import { attemptDisableReadOnly } from './store/app/actions/readonly';
import {
  selectBottomPanel,
  selectCurrentRule,
  selectHasEditingLock,
  selectLeftPanel,
  selectProjectSlug,
  selectReadOnly,
  selectRevisionSlug,
  selectRightPanel,
  selectShowDiagnosticsWindow,
  selectShowScoringOverview,
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

  const hasEditingLock = useSelector(selectHasEditingLock);
  const isReadOnly = useSelector(selectReadOnly);
  const [isReadOnlyWarningDismissed, setIsReadOnlyWarningDismissed] = useState(false);
  const [isAttemptDisableReadOnlyFailed, setIsAttemptDisableReadOnlyFailed] = useState(false);

  const shouldShowLockError = !hasEditingLock && !isReadOnly;
  const shouldShowReadOnlyWarning = !isLoading && isReadOnly && !isReadOnlyWarningDismissed;
  const shouldShowEditor =
    !isLoading && (hasEditingLock || isReadOnly) && !shouldShowReadOnlyWarning;

  const alertSeverity = isAttemptDisableReadOnlyFailed || shouldShowLockError ? 'warning' : 'info';

  /* console.log('RENDER IT', {
    shouldShowEditor,
    shouldShowLockError,
    shouldShowReadOnlyWarning,
    isAppVisible,
    hasEditingLock,
  }); */

  const showDiagnosticsWindow = useSelector(selectShowDiagnosticsWindow);
  const showScoringOverview = useSelector(selectShowScoringOverview);

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

  const dismissReadOnlyWarning = async ({ attemptEdit }: { attemptEdit: boolean }) => {
    if (attemptEdit) {
      const attemptResult = await dispatch(attemptDisableReadOnly());
      if ((attemptResult as any).meta.requestStatus !== 'fulfilled') {
        const errorCode = (attemptResult as any)?.payload?.error;
        if (errorCode === 'SESSION_EXPIRED') {
          window.location.reload();
        }
        setIsAttemptDisableReadOnlyFailed(true);
        return;
      }
    }
    setIsReadOnlyWarningDismissed(true);
  };

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
    const appConfig = {
      paths: props.paths,
      isAdmin: props.isAdmin,
      projectSlug: props.projectSlug,
      revisionSlug: props.revisionSlug,
      partComponentTypes: props.partComponentTypes,
      activityTypes: props.activityTypes,
    };
    dispatch(setInitialConfig(appConfig));
  }, [props]);

  useEffect(() => {
    window.addEventListener('beforeunload', async () =>
      isFirefox
        ? setTimeout(async () => {
            await dispatch(releaseEditingLock());
          })
        : await dispatch(releaseEditingLock()),
    );

    let initTimeout: any = null;
    if (hasEditingLock || (isReadOnly && isReadOnlyWarningDismissed)) {
      initTimeout = setTimeout(() => {
        if (props.content) {
          const appConfig = {
            paths: props.paths,
            isAdmin: props.isAdmin,
            projectSlug: props.projectSlug,
            revisionSlug: props.revisionSlug,
            partComponentTypes: props.partComponentTypes,
            activityTypes: props.activityTypes,
          };
          dispatch(initializeFromContext({ context: props.content, config: appConfig }));
        }
        setIsAppVisible(true);
      }, 500);
    }
    const loadingTimeout = setTimeout(() => {
      setIsLoading(false);
    }, 2000);

    return () => {
      window.removeEventListener('beforeunload', async () => await dispatch(releaseEditingLock()));
      if (initTimeout) {
        clearTimeout(initTimeout);
      }
      if (loadingTimeout) {
        clearTimeout(loadingTimeout);
      }
    };
  }, [props, hasEditingLock, isReadOnly, isReadOnlyWarningDismissed]);

  return (
    <>
      {isLoading && (
        <div id="aa-loading">
          <div className="loader spinner-border text-primary" role="status">
            <span className="sr-only">Loading...</span>
          </div>
        </div>
      )}
      {shouldShowEditor && (
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

      {shouldShowReadOnlyWarning && (
        <Alert variant={alertSeverity}>
          <Alert.Heading>Opening in Read-Only Mode</Alert.Heading>
          {!isAttemptDisableReadOnlyFailed && (
            <p>
              You are about to open this page in read-only mode. You are able to view the contents
              of this page, but any changes you make will not be saved. You may instead attempt to
              open in editing mode, or open a preview of the page.
            </p>
          )}
          {isAttemptDisableReadOnlyFailed && (
            <p>
              Unfortunately, we were unable to disable read-only mode. Another author currently has
              the page locked for editing. Please try again later. In the meantime, you may continue
              in Read Only mode or open a preview of the page.
            </p>
          )}
          <hr />
          <div style={{ textAlign: 'center' }}>
            <Button
              variant={`outline-${alertSeverity}`}
              className="text-dark"
              onClick={() => dismissReadOnlyWarning({ attemptEdit: false })}
            >
              Continue In Read-Only Mode
            </Button>{' '}
            {!isAttemptDisableReadOnlyFailed && (
              <>
                <Button
                  variant={`outline-${alertSeverity}`}
                  className="text-dark"
                  onClick={() => dismissReadOnlyWarning({ attemptEdit: true })}
                >
                  Open In Edit Mode
                </Button>{' '}
              </>
            )}
            <Button
              variant={`outline-${alertSeverity}`}
              className="text-dark"
              onClick={() => window.open(url, windowName)}
            >
              Open Preview <i className="las la-external-link-alt ml-1"></i>
            </Button>
          </div>
        </Alert>
      )}

      {showDiagnosticsWindow && <DiagnosticsWindow />}

      {showScoringOverview && <ScoringOverview />}
    </>
  );
};

const ReduxApp: React.FC<AuthoringProps> = (props) => (
  <Provider store={store}>
    <Authoring {...props} />
  </Provider>
);

export default ReduxApp;
