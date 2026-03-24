import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { getModeFromLocalStorage } from 'components/misc/DarkModeSelector';
import { isFirefox } from 'utils/browser';
import { AppsignalContext, ErrorBoundary } from '../../components/common/ErrorBoundary';
import { initAppSignal, updateAppSignalMetadata } from '../../utils/appsignal';
import { IActivity, selectAllActivities } from '../delivery/store/features/activities/slice';
import { selectSequence } from '../delivery/store/features/groups/selectors/deck';
import { AuthoringExpertPageEditor } from './AuthoringExpertPageEditor';
import { AuthoringFlowchartPageEditor } from './AuthoringFlowchartPageEditor';
import { ModalContainer } from './components/AdvancedAuthoringModal';
import { FlowchartEditor } from './components/Flowchart/FlowchartEditor';
import { onboardWizardComplete } from './components/Flowchart/flowchart-actions/onboard-wizard-complete';
import { verifyFlowchartLesson } from './components/Flowchart/flowchart-actions/verify-flowchart-lesson';
import { OnboardWizard } from './components/Flowchart/onboard-wizard/OnboardWizard';
import { validateScreen } from './components/Flowchart/screens/screen-validation';
import { InvalidScreenWarning } from './components/Flowchart/toolbar/InvalidScreenWarning';
import DiagnosticsWindow from './components/Modal/DiagnosticsWindow';
import ScoringOverview from './components/Modal/ScoringOverview';
import { handleShellReadOnlyToggle } from './readOnlyBridge';
import { flushPendingActivitySaves } from './store/activities/actions/saveActivity';
import { releaseEditingLock } from './store/app/actions/locking';
import {
  AppConfig,
  ApplicationMode,
  selectAppMode,
  selectBottomPanel,
  selectCurrentRule,
  selectEditMode,
  selectHasEditingLock,
  selectLeftPanel,
  selectReadOnly,
  selectRightPanel,
  selectShowDiagnosticsWindow,
  selectShowScoringOverview,
  selectTopPanel,
  setRevisionSlug as setAppRevisionSlug,
  setInitialConfig,
  setPanelState,
} from './store/app/slice';
import { initializeFromContext } from './store/page/actions/initializeFromContext';
import { flushPendingPageSave } from './store/page/actions/savePage';
import { setRevisionSlug as setPageRevisionSlug, setTitle } from './store/page/slice';
import { PageContext } from './types';

export interface AuthoringProps {
  isAdmin: boolean;
  projectSlug: string;
  revisionSlug: string;
  content: PageContext;
  creationModeHint?: ApplicationMode;
  activityTypes?: any[];
  partComponentTypes?: any[];
  resourceId?: number;
  paths: Record<string, string>;
  appsignalKey: string | null;
  initialSidebarExpanded: boolean;
}

const Authoring: React.FC<AuthoringProps> = (props: AuthoringProps) => {
  const {
    paths,
    isAdmin,
    projectSlug,
    revisionSlug,
    partComponentTypes,
    activityTypes,
    content,
    resourceId,
  } = props;
  const dispatch = useDispatch();
  const initializedRevisionRef = useRef<string | null>(null);
  const initializedResourceIdRef = useRef<number | undefined>(undefined);
  const previewRequestRef = useRef<{
    url: string;
    windowName: string;
    previewWindow: Window | null;
  } | null>(null);
  const hasEditingLockRef = useRef(false);
  const isUnloadingRef = useRef(false);
  const allowTriggers = props.content.optionalContentTypes?.triggers === true;

  const [isAppVisible, setIsAppVisible] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [invalidScreens, setInvalidScreens] = useState<IActivity[]>([]);

  const hasEditingLock = useSelector(selectHasEditingLock);
  const isReadOnly = useSelector(selectReadOnly);
  const activities = useSelector(selectAllActivities);
  const sequence = useSelector(selectSequence);
  const hasReadonlyBootstrapActivities = activities.some(
    (activity) =>
      typeof activity.resourceId === 'string' &&
      String(activity.resourceId).startsWith('readonly_'),
  );

  const editingMode = useSelector(selectEditMode);

  const readyToEdit = !isLoading && (hasEditingLock || isReadOnly);

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
    isAppVisible,
    hasEditingLock,
  }); */

  const showDiagnosticsWindow = useSelector(selectShowDiagnosticsWindow);
  const showScoringOverview = useSelector(selectShowScoringOverview);

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
  const [sidebarExpanded, setSidebarExpanded] = useState(props.initialSidebarExpanded);

  const openPreviewWindow = (
    url: string,
    windowName: string,
    previewWindow: Window | null = null,
  ) => {
    if (previewWindow && !previewWindow.closed) {
      previewWindow.location.href = url;
      previewWindow.focus();
      return;
    }

    window.open(url, windowName);
  };

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

  const flushPendingAdaptiveSaves = useCallback(async () => {
    await Promise.all([flushPendingPageSave(), flushPendingActivitySaves()]);
  }, []);

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
    hasEditingLockRef.current = hasEditingLock;
  }, [hasEditingLock]);

  useEffect(() => {
    const beforeUnloadHandler = () => {
      if (!hasEditingLockRef.current) {
        return;
      }

      isUnloadingRef.current = true;
      void flushPendingAdaptiveSaves();

      if (isFirefox) {
        setTimeout(() => {
          void dispatch(releaseEditingLock());
        });
      } else {
        void dispatch(releaseEditingLock());
      }
    };

    window.addEventListener('beforeunload', beforeUnloadHandler);

    return () => {
      window.removeEventListener('beforeunload', beforeUnloadHandler);

      if (!isUnloadingRef.current && hasEditingLockRef.current) {
        void flushPendingAdaptiveSaves().finally(() => {
          void dispatch(releaseEditingLock());
        });
      }
    };
  }, [dispatch, flushPendingAdaptiveSaves]);

  useEffect(() => {
    const appConfig: AppConfig = {
      paths,
      isAdmin,
      projectSlug,
      revisionSlug,
      allowTriggers,
      partComponentTypes,
      activityTypes,
      allObjectives: content.allObjectives || [],
      applicationMode:
        content.content?.custom?.contentMode === 'flowchart' ? 'flowchart' : 'expert',
    };
    dispatch(setInitialConfig(appConfig));
  }, [
    activityTypes,
    allowTriggers,
    content,
    dispatch,
    isAdmin,
    partComponentTypes,
    paths,
    projectSlug,
    revisionSlug,
  ]);

  useEffect(() => {
    let cancelled = false;

    const initialize = async () => {
      if (!(hasEditingLock || isReadOnly)) {
        if (!cancelled) {
          setIsLoading(true);
          setIsAppVisible(false);
        }
        return;
      }

      const shouldMaterializeReadonlyBootstrap =
        hasEditingLock && !isReadOnly && hasReadonlyBootstrapActivities;

      if (initializedRevisionRef.current === revisionSlug && !shouldMaterializeReadonlyBootstrap) {
        if (!cancelled) {
          setIsLoading(false);
          setIsAppVisible(true);
        }
        return;
      }

      if (
        initializedResourceIdRef.current !== undefined &&
        initializedResourceIdRef.current === resourceId
      ) {
        if (shouldMaterializeReadonlyBootstrap) {
          initializedRevisionRef.current = null;
          initializedResourceIdRef.current = undefined;
        } else {
          if (!cancelled) {
            initializedRevisionRef.current = revisionSlug;
            setIsLoading(false);
            setIsAppVisible(true);
          }
          return;
        }
      }

      if (!cancelled) {
        setIsLoading(true);
      }

      if (content) {
        const appConfig = {
          paths,
          isAdmin,
          projectSlug,
          revisionSlug,
          allowTriggers,
          partComponentTypes,
          activityTypes,
        };

        await dispatch(initializeFromContext({ context: content, config: appConfig }));
      }

      if (!cancelled) {
        initializedRevisionRef.current = revisionSlug;
        initializedResourceIdRef.current = resourceId;
        setIsAppVisible(true);
        setIsLoading(false);
      }
    };

    initialize();

    return () => {
      cancelled = true;
    };
  }, [
    activityTypes,
    allowTriggers,
    content,
    dispatch,
    hasEditingLock,
    hasReadonlyBootstrapActivities,
    isAdmin,
    isReadOnly,
    partComponentTypes,
    paths,
    projectSlug,
    resourceId,
    revisionSlug,
  ]);

  useEffect(() => {
    const editable = hasEditingLock && !isReadOnly;
    (window as any).ReactToLiveView?.pushEvent('authoring_title_lock_state_changed', {
      editable,
    });
  }, [hasEditingLock, isReadOnly]);

  useEffect(() => {
    (window as any).ReactToLiveView?.pushEvent('authoring_readonly_state_changed', {
      readonly: isReadOnly,
    });
  }, [isReadOnly]);

  useEffect(() => {
    (window as any).ReactToLiveView?.pushEvent('authoring_preview_state_changed', {
      enabled: readyToEdit && isAppVisible && !shouldShowOnboarding,
    });
  }, [isAppVisible, readyToEdit, shouldShowOnboarding]);

  useEffect(() => {
    const onReadOnlyToggleRequested = async (event: Event) => {
      const detail = (event as CustomEvent).detail as { readonly: boolean };

      if (detail.readonly && hasEditingLock) {
        await flushPendingAdaptiveSaves();
      }

      const result = await handleShellReadOnlyToggle({
        desiredReadOnly: detail.readonly,
        hasEditingLock,
        dispatch: dispatch as any,
        reload: () => window.location.reload(),
      });

      if (result.sessionExpired) {
        return;
      }

      if (result.errorMessage) {
        (window as any).ReactToLiveView?.pushEvent('authoring_readonly_toggle_failed', {
          message: result.errorMessage,
          readonly: result.readonly,
        });
        (window as any).ReactToLiveView?.pushEvent('authoring_readonly_state_changed', {
          readonly: result.readonly,
        });
      }
    };
    window.addEventListener('phx:adaptive_readonly_toggle_requested', onReadOnlyToggleRequested);
    return () =>
      window.removeEventListener(
        'phx:adaptive_readonly_toggle_requested',
        onReadOnlyToggleRequested,
      );
  }, [dispatch, flushPendingAdaptiveSaves, hasEditingLock]);

  useEffect(() => {
    const onTitleUpdated = (event: Event) => {
      const detail = (event as CustomEvent).detail as {
        title: string;
        revision_slug: string;
      };

      dispatch(setTitle({ title: detail.title }));
      dispatch(setPageRevisionSlug({ revisionSlug: detail.revision_slug }));
      dispatch(setAppRevisionSlug({ revisionSlug: detail.revision_slug }));
      updateAppSignalMetadata(appsignal, 'Advanced Authoring', {
        projectSlug,
        revisionSlug: detail.revision_slug,
        resourceId: String(resourceId),
      });
    };

    window.addEventListener('phx:authoring_page_title_updated', onTitleUpdated);
    return () => window.removeEventListener('phx:authoring_page_title_updated', onTitleUpdated);
  }, [appsignal, dispatch, projectSlug, resourceId]);

  useEffect(() => {
    const onPreviewRequested = async (event: Event) => {
      const detail = (event as CustomEvent).detail as {
        url: string;
        window_name: string;
      };

      if (!isFlowchartMode) {
        openPreviewWindow(detail.url, detail.window_name);
        return;
      }

      const previewWindow = window.open('', detail.window_name);
      previewRequestRef.current = {
        url: detail.url,
        windowName: detail.window_name,
        previewWindow,
      };

      await dispatch(verifyFlowchartLesson({}) as any);

      const nextInvalidScreens = activities.filter(
        (activity) => validateScreen(activity, activities, sequence).length > 0,
      );

      if (nextInvalidScreens.length > 0) {
        if (previewWindow && !previewWindow.closed) {
          previewWindow.close();
        }
        setInvalidScreens(nextInvalidScreens);
        return;
      }

      openPreviewWindow(detail.url, detail.window_name, previewWindow);
    };

    window.addEventListener('phx:authoring_preview_requested', onPreviewRequested);
    return () => window.removeEventListener('phx:authoring_preview_requested', onPreviewRequested);
  }, [activities, dispatch, isFlowchartMode, sequence]);

  const onAcceptInvalidPreview = () => {
    if (previewRequestRef.current) {
      openPreviewWindow(
        previewRequestRef.current.url,
        previewRequestRef.current.windowName,
        previewRequestRef.current.previewWindow,
      );
      previewRequestRef.current = null;
    }
    setInvalidScreens([]);
  };

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

          {showDiagnosticsWindow && <DiagnosticsWindow />}

          {showScoringOverview && <ScoringOverview />}

          {invalidScreens.length > 0 && (
            <InvalidScreenWarning
              screens={invalidScreens}
              onAccept={onAcceptInvalidPreview}
              onCancel={() => {
                previewRequestRef.current = null;
                setInvalidScreens([]);
              }}
            />
          )}

          {shouldShowOnboarding && (
            <OnboardWizard
              onSetupComplete={onOnboardComplete}
              initialTitle={props.content.title}
              presetMode={props.creationModeHint}
            />
          )}
        </ModalContainer>
      </ErrorBoundary>
    </AppsignalContext.Provider>
  );
};

export default Authoring;
