import React, { useEffect, useMemo, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { getModeFromLocalStorage } from 'components/misc/DarkModeSelector';
import { isFirefox } from 'utils/browser';
import { AppsignalContext, ErrorBoundary } from '../../components/common/ErrorBoundary';
import { initAppSignal } from '../../utils/appsignal';
import { AuthoringExpertPageEditor } from './AuthoringExpertPageEditor';
import { AuthoringFlowchartPageEditor } from './AuthoringFlowchartPageEditor';
import { ReadOnlyWarning } from './ReadOnlyWarning';
import { ModalContainer } from './components/AdvancedAuthoringModal';
import { FlowchartEditor } from './components/Flowchart/FlowchartEditor';
import { onboardWizardComplete } from './components/Flowchart/flowchart-actions/onboard-wizard-complete';
import { OnboardWizard } from './components/Flowchart/onboard-wizard/OnboardWizard';
import DiagnosticsWindow from './components/Modal/DiagnosticsWindow';
import ScoringOverview from './components/Modal/ScoringOverview';
import { releaseEditingLock } from './store/app/actions/locking';
import { attemptDisableReadOnly } from './store/app/actions/readonly';
import {
  AppConfig,
  ApplicationMode,
  selectAppMode,
  selectBottomPanel,
  selectCurrentRule,
  selectEditMode,
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
  appsignalKey: string | null;
  initialSidebarExpanded: boolean;
}

const Authoring: React.FC<AuthoringProps> = (props: AuthoringProps) => {
  const dispatch = useDispatch();

  const [isAppVisible, setIsAppVisible] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  const hasEditingLock = useSelector(selectHasEditingLock);
  const isReadOnly = useSelector(selectReadOnly);
  const [isReadOnlyWarningDismissed, setIsReadOnlyWarningDismissed] = useState(false);
  const [isAttemptDisableReadOnlyFailed, setIsAttemptDisableReadOnlyFailed] = useState(false);

  const editingMode = useSelector(selectEditMode);

  const shouldShowLockError = !hasEditingLock && !isReadOnly;
  const shouldShowReadOnlyWarning = !isLoading && isReadOnly && !isReadOnlyWarningDismissed;

  const readyToEdit = !isLoading && (hasEditingLock || isReadOnly) && !shouldShowReadOnlyWarning;

  const alertSeverity = isAttemptDisableReadOnlyFailed || shouldShowLockError ? 'warning' : 'info';

  const appsignal = useMemo(
    () =>
      initAppSignal(props.appsignalKey, 'Advanced Authoring', {
        projectSlug: props.projectSlug,
        revisionSlug: props.revisionSlug,
        resourceId: String(props.resourceId),
      }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [props.appsignalKey],
  );

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
  const applicationMode = useSelector(selectAppMode);

  const isFlowchartMode = applicationMode === 'flowchart';
  const isExpertMode = applicationMode === 'expert';
  const shouldShowPageEditor = readyToEdit && (editingMode === 'page' || isExpertMode);
  const shouldShowFlowchartEditor = readyToEdit && editingMode === 'flowchart';

  const shouldShowOnboarding =
    props.content.content?.custom?.contentMode === undefined &&
    props.content.content?.model?.length === 0;

  const panelState = {
    left: leftPanelState,
    right: rightPanelState,
    top: topPanelState,
    bottom: bottomPanelState,
  };

  const url = `/authoring/project/${projectSlug}/preview/${revisionSlug}`;
  const windowName = `preview-${projectSlug}`;

  const [sidebarExpanded, setSidebarExpanded] = useState(props.initialSidebarExpanded);

  const handleSidebarExpanded = () => {
    setSidebarExpanded((prev) => !prev);
  };

  const onOnboardComplete = (appMode: ApplicationMode, title: string) => {
    const { revisionSlug } = props;
    const pageContent = props.content.content;
    const projectSlug = props.content.projectSlug || '';
    props.content.allObjectives || [];
    onboardWizardComplete(title, projectSlug, revisionSlug, appMode, pageContent);
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
    console.log('handlePanelStateChange', { top, right, left, bottom });
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
      document.body.classList.add('overflow-hidden'); // prevents double scroll bars
    }

    if (!isAppVisible) {
      // reset forced light mode
      switch (getModeFromLocalStorage()) {
        case 'dark':
          document.documentElement.classList.add('dark');
          break;
        case 'auto':
          break;
        case 'light':
          break;
      }
      document.body.classList.remove('overflow-hidden');
    }
    return () => {
      document.body.classList.remove('overflow-hidden');
    };
  }, [isAppVisible]);

  useEffect(() => {
    const appConfig: AppConfig = {
      paths: props.paths,
      isAdmin: props.isAdmin,
      projectSlug: props.projectSlug,
      revisionSlug: props.revisionSlug,
      partComponentTypes: props.partComponentTypes,
      activityTypes: props.activityTypes,
      allObjectives: props.content.allObjectives || [],
      applicationMode:
        props.content.content?.custom?.contentMode === 'flowchart' ? 'flowchart' : 'expert',
    };
    dispatch(setInitialConfig(appConfig));
  }, [dispatch, props]);

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
  }, [props, hasEditingLock, isReadOnly, isReadOnlyWarningDismissed, dispatch]);

  return (
    <AppsignalContext.Provider value={appsignal}>
      <button
        role="update sidebar state on React"
        className="hidden"
        onClick={() => {
          handleSidebarExpanded();
        }}
      ></button>
      <ErrorBoundary>
        <ModalContainer>
          {isLoading && (
            <div id="aa-loading" className="!z-10 -mt-2">
              <div className="loader spinner-border text-primary" role="status">
                <span className="sr-only">Loading...</span>
              </div>
            </div>
          )}

          {shouldShowPageEditor && isExpertMode && (
            <AuthoringExpertPageEditor
              currentRule={currentRule}
              handlePanelStateChange={handlePanelStateChange}
              panelState={panelState}
              sidebarExpanded={sidebarExpanded}
            />
          )}

          {shouldShowPageEditor && isFlowchartMode && (
            <AuthoringFlowchartPageEditor
              handlePanelStateChange={handlePanelStateChange}
              panelState={panelState}
              sidebarExpanded={sidebarExpanded}
            />
          )}

          {shouldShowFlowchartEditor && <FlowchartEditor sidebarExpanded={sidebarExpanded} />}

          {shouldShowReadOnlyWarning && (
            <ReadOnlyWarning
              isAttemptDisableReadOnlyFailed={isAttemptDisableReadOnlyFailed}
              alertSeverity={alertSeverity}
              dismissReadOnlyWarning={dismissReadOnlyWarning}
              url={url}
              windowName={windowName}
            />
          )}

          {showDiagnosticsWindow && <DiagnosticsWindow />}

          {showScoringOverview && <ScoringOverview />}

          {shouldShowOnboarding && (
            <OnboardWizard onSetupComplete={onOnboardComplete} initialTitle={props.content.title} />
          )}
        </ModalContainer>
      </ErrorBoundary>
    </AppsignalContext.Provider>
  );
};

export default Authoring;
