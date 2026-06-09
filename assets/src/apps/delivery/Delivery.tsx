import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import useWindowSize from 'components/hooks/useWindowSize';
import { getModeFromLocalStorage } from 'components/misc/DarkModeSelector';
import { janus_std } from 'adaptivity/janus-scripts/builtin_functions';
import { defaultGlobalEnv, evalScript } from 'adaptivity/scripting';
import { isDarkMode } from 'utils/browser';
import { AdaptiveDialogueBridge } from './components/AdaptiveDialogueBridge';
import PreviewTools from './components/PreviewTools';
import { DeadlineTimer } from './layouts/deck/DeadlineTimer';
import DeckLayoutView from './layouts/deck/DeckLayoutView';
import ScreenIdleTimeOutDialog from './layouts/deck/IdleTimeOutDialog';
import LessonFinishedDialog from './layouts/deck/LessonFinishedDialog';
import RestartLessonDialog from './layouts/deck/RestartLessonDialog';
import { LayoutProps } from './layouts/layouts';
import {
  selectLessonEnd,
  selectRestartLesson,
  selectScreenIdleTimeOutTriggered,
  setScreenIdleTimeOutTriggered,
} from './store/features/adaptivity/slice';
import { selectCurrentActivityTreeAttemptState } from './store/features/groups/selectors/deck';
import { LayoutType, selectCurrentGroup } from './store/features/groups/slice';
import { loadInitialPageState } from './store/features/page/actions/loadInitialPageState';
import { selectScreenIdleExpirationTime } from './store/features/page/slice';

export interface DeliveryProps {
  resourceId: number;
  sectionSlug: string;
  projectSlug: string;
  userId: number;
  userName: string;
  pageTitle: string;
  pageSlug: string;
  content: any;
  resourceAttemptState: any;
  resourceAttemptGuid: string;
  resourceAttemptNumber?: number;
  activityGuidMapping: any;
  previewSequenceId?: string;
  previewMode?: boolean;
  isInstructor: boolean;
  enableHistory?: boolean;
  activityTypes?: any[];
  graded: boolean;
  overviewURL: string;
  finalizeGradedURL: string;
  blobStorageProvider: 'new' | 'deprecated';
  screenIdleTimeOutInSeconds?: number;
  reviewMode?: boolean;
  preserveCapiIframeSize?: boolean;
  signoutUrl?: string;
  currentServerTime?: number;
  effectiveEndTime?: number;
  lateSubmit?: 'allow' | 'disallow';
  isAdmin?: boolean;
  isAuthor?: boolean;
  debuggerURL?: string;
}

export const shouldHideLessonFinishedCloseButton = (
  previewMode: boolean,
  displayApplicationChrome: boolean | undefined,
) => !!displayApplicationChrome && !previewMode;

const adaptiveIframeHeightMessageType = 'oli:adaptive-content-height';
const adaptiveIframeHeightRequestType = 'oli:request-adaptive-content-height';
const minimumAdaptiveIframeHeight = 650;
const adaptiveIframeContentSelectors = ['#stage-stage', '.stage-content-wrapper > .content'].join(
  ',',
);
const adaptiveIframeFallbackContentSelectors = ['[data-adaptive-delivery-root]', '.mainView'].join(
  ',',
);
const adaptivePartTagPrefix = 'janus-';
const capiIframePartTagName = 'janus-capi-iframe';
const adaptiveRootSelector = '[data-adaptive-delivery-root]';

const isHTMLElement = (element?: Element | null): element is HTMLElement => {
  const elementWindow = element?.ownerDocument.defaultView;

  return !!elementWindow && element instanceof elementWindow.HTMLElement;
};

const finiteNumber = (value: unknown) => {
  const numberValue = typeof value === 'number' ? value : Number(value);

  return Number.isFinite(numberValue) ? numberValue : undefined;
};

const usesResponsiveAdaptiveLayout = () => {
  const root = document.querySelector(adaptiveRootSelector);

  return root?.getAttribute('data-adaptive-responsive-layout') === 'true';
};

const getElementHeight = (element?: Element | null) => {
  if (!isHTMLElement(element)) {
    return 0;
  }

  return Math.max(
    element.scrollHeight || 0,
    element.offsetHeight || 0,
    element.getBoundingClientRect().height || 0,
    element.getBoundingClientRect().bottom + window.scrollY,
  );
};

const getElementLayoutHeight = (element?: Element | null) => {
  if (!isHTMLElement(element)) {
    return 0;
  }

  return Math.max(element.offsetHeight || 0, element.getBoundingClientRect().height || 0);
};

const getElementVisualBottom = (element?: Element | null) => {
  if (!isHTMLElement(element)) {
    return 0;
  }

  return element.getBoundingClientRect().bottom + window.scrollY;
};

const getAuthoredPartVisualBottom = (element?: Element | null) => {
  if (!isHTMLElement(element)) {
    return 0;
  }

  const modelAttribute = element.getAttribute('model');
  const top = element.getBoundingClientRect().top + window.scrollY;

  if (!modelAttribute) {
    return getElementVisualBottom(element);
  }

  try {
    const model = JSON.parse(modelAttribute);
    const height = finiteNumber(model?.height);

    return height === undefined ? getElementVisualBottom(element) : top + height;
  } catch (_e) {
    return getElementVisualBottom(element);
  }
};

const getIntrinsicAdaptiveElementHeight = (element?: Element | null) => {
  if (!isHTMLElement(element)) {
    return 0;
  }

  const partElements = Array.from(element.querySelectorAll('*')).filter((child) =>
    child.tagName.toLowerCase().startsWith(adaptivePartTagPrefix),
  );

  if (partElements.length === 0) {
    return 0;
  }

  const partHeight = usesResponsiveAdaptiveLayout()
    ? getElementVisualBottom
    : getAuthoredPartVisualBottom;
  const partContentHeight = Math.max(...partElements.map(partHeight), 0);

  return partContentHeight;
};

const getMaxElementHeight = (elements: Element[]) =>
  Math.max(...elements.map(getElementHeight), minimumAdaptiveIframeHeight);

const getMaxElementLayoutHeight = (elements: Element[]) =>
  Math.max(...elements.map(getElementLayoutHeight), minimumAdaptiveIframeHeight);

const getMaxIntrinsicAdaptiveElementHeight = (elements: Element[]) =>
  Math.max(...elements.map(getIntrinsicAdaptiveElementHeight), minimumAdaptiveIframeHeight);

const getDocumentHeight = () =>
  Math.max(getElementHeight(document.body), getElementHeight(document.documentElement));

export const getAdaptiveContentHeight = (contentElement?: HTMLElement | null) => {
  const contentElements = Array.from(document.querySelectorAll(adaptiveIframeContentSelectors));

  if (contentElements.length > 0) {
    const intrinsicHeight = getMaxIntrinsicAdaptiveElementHeight(contentElements);

    if (intrinsicHeight === minimumAdaptiveIframeHeight) {
      return minimumAdaptiveIframeHeight;
    }

    const adaptiveContainerHeight = getMaxElementLayoutHeight(contentElements);
    const hasCapiIframe = contentElements.some((element) =>
      element.querySelector(capiIframePartTagName),
    );
    const adaptiveOverflowHeight = hasCapiIframe
      ? 0
      : Math.max(
          ...contentElements.map(
            (element) => getElementHeight(element) - getElementLayoutHeight(element),
          ),
          0,
        );
    const surroundingDocumentHeight = Math.max(
      getDocumentHeight() - Math.max(adaptiveContainerHeight, intrinsicHeight),
      0,
    );

    return intrinsicHeight + Math.max(adaptiveOverflowHeight, surroundingDocumentHeight);
  }

  const fallbackContentElements = Array.from(
    document.querySelectorAll(adaptiveIframeFallbackContentSelectors),
  );

  if (contentElement || fallbackContentElements.length > 0) {
    return minimumAdaptiveIframeHeight;
  }

  const measuredContentHeight = getMaxElementHeight([...fallbackContentElements]);
  const measuredDocumentHeight = getDocumentHeight();

  return Math.max(measuredContentHeight, measuredDocumentHeight, minimumAdaptiveIframeHeight);
};

const Delivery: React.FC<DeliveryProps> = ({
  userId,
  userName,
  resourceId,
  sectionSlug,
  pageTitle = '',
  pageSlug,
  content,
  resourceAttemptGuid,
  resourceAttemptState,
  resourceAttemptNumber = 1,
  activityGuidMapping,
  previewSequenceId,
  signoutUrl,
  activityTypes = [],
  previewMode = false,
  isInstructor = false,
  enableHistory = false,
  graded = false,
  overviewURL = '',
  finalizeGradedURL = '',
  blobStorageProvider = 'deprecated',
  screenIdleTimeOutInSeconds = 1800,
  reviewMode = false,
  preserveCapiIframeSize = false,
  currentServerTime = 0,
  effectiveEndTime = 0,
  lateSubmit = 'allow',
  isAdmin,
  isAuthor,
  debuggerURL,
}) => {
  const dispatch = useDispatch();
  const currentGroup = useSelector(selectCurrentGroup);
  const currentActivityTreeAttemptState = useSelector(selectCurrentActivityTreeAttemptState);
  const restartLesson = useSelector(selectRestartLesson);
  const screenIdleExpirationTime = useSelector(selectScreenIdleExpirationTime);
  const screenIdleTimeOutTriggered = useSelector(selectScreenIdleTimeOutTriggered);

  const [currentTheme, setCurrentTheme] = useState('auto');
  // Gives us the deadline for this assessment to be completed by.
  // We subtract out the server time and add in our local time in case the client system clock is off.
  // Measured in milliseconds-epoch to match Date.now()
  const localDeadline = useMemo(() => {
    if (!effectiveEndTime) {
      return Number.MAX_SAFE_INTEGER;
    }
    return effectiveEndTime - currentServerTime + Date.now();
  }, [currentServerTime, effectiveEndTime]);

  let LayoutView: React.FC<LayoutProps> = () => <div>Unknown Layout</div>;
  if (currentGroup?.layout === LayoutType.DECK) {
    LayoutView = DeckLayoutView;
  }

  //Need to start the warning 5 minutes before session expires
  const screenIdleWarningTime = screenIdleTimeOutInSeconds * 1000 - 300000;

  useEffect(() => {
    //if it's preview mode, we don't need to do anything
    if (!screenIdleExpirationTime || previewMode || reviewMode) {
      return;
    }
    const timer = setTimeout(() => {
      dispatch(setScreenIdleTimeOutTriggered({ screenIdleTimeOutTriggered: true }));
    }, screenIdleWarningTime);
    return () => clearTimeout(timer);
  }, [screenIdleExpirationTime]);

  const handleUserThemePreferende = () => {
    const isDarkModeThemeEnabled = content?.custom?.darkModeSetting;
    // If dark mode is disabled, do not apply the dark theme to the lesson.
    // If dark mode is enabled, apply the theme based on the student's selected theme (default current behavior).
    if (!isDarkModeThemeEnabled) {
      setCurrentTheme('light');
    } else {
      switch (getModeFromLocalStorage()) {
        case 'dark':
          setCurrentTheme('dark');
          break;
        case 'auto':
          if (isDarkMode()) {
            setCurrentTheme('dark');
          } else {
            setCurrentTheme('light');
          }
          break;
        case 'light':
          setCurrentTheme('light');
          break;
      }
    }
  };
  useEffect(() => {
    setInitialPageState();
    handleUserThemePreferende();
  }, []);

  useEffect(() => {
    const displayRefreshWarningPopup = content?.custom?.displayRefreshWarningPopup || true;

    // Only show the prompt if it's not in preview mode and not in review mode
    if (displayRefreshWarningPopup && isInstructor && !previewMode && !reviewMode) {
      const unloadCallback = (event: any) => {
        event.preventDefault();
        event.returnValue = '';
        return '';
      };

      window.addEventListener('beforeunload', unloadCallback);
      return () => window.removeEventListener('beforeunload', unloadCallback);
    }
  }, [content?.custom?.displayRefreshWarningPopup]);

  const setInitialPageState = () => {
    // the standard lib relies on first the userId and userName session variables being set
    const userScript = `let session.userId = ${userId};let session.userName = "${
      userName || 'guest'
    }";`;
    evalScript(userScript, defaultGlobalEnv);
    evalScript(janus_std, defaultGlobalEnv);

    dispatch(
      loadInitialPageState({
        userId,
        userName,
        resourceId,
        sectionSlug,
        pageTitle,
        pageSlug,
        content,
        resourceAttemptGuid,
        resourceAttemptState,
        resourceAttemptNumber,
        activityGuidMapping,
        previewSequenceId,
        previewMode: !!previewMode,
        isInstructor,
        activityTypes,
        enableHistory,
        showHistory: false,
        score: 0,
        graded,
        activeEverapp: 'none',
        overviewURL,
        finalizeGradedURL,
        blobStorageProvider,
        screenIdleTimeOutInSeconds,
        reviewMode,
        preserveCapiIframeSize,
        debuggerURL,
      }),
    );
  };
  const parentDivClasses: string[] = [];
  if (content?.custom?.viewerSkin) {
    parentDivClasses.push(`skin-${content?.custom?.viewerSkin}`);
  }
  const dialogImageUrl = content?.custom?.logoutPanelImageURL;
  const dialogMessage = content?.custom?.logoutMessage;
  const hideLessonFinishedCloseButton = shouldHideLessonFinishedCloseButton(
    !!previewMode,
    content?.displayApplicationChrome,
  );
  const insightsStageOnlyPreview = !!content?.custom?.insightsStageOnlyPreview;
  const adaptiveDialogueBridgeEnabled = !!content?.advancedDelivery && !previewMode && !reviewMode;
  const currentActivityAttemptGuid =
    currentActivityTreeAttemptState?.[currentActivityTreeAttemptState.length - 1]?.attemptGuid;
  const shouldReportAdaptiveIframeHeight = !!content?.displayApplicationChrome && !previewMode;
  const deliveryRootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!shouldReportAdaptiveIframeHeight || window.parent === window) {
      return;
    }

    let animationFrame: number | undefined;

    const reportHeight = () => {
      if (animationFrame) {
        window.cancelAnimationFrame(animationFrame);
      }

      animationFrame = window.requestAnimationFrame(() => {
        window.parent.postMessage(
          {
            type: adaptiveIframeHeightMessageType,
            height: getAdaptiveContentHeight(deliveryRootRef.current),
          },
          window.location.origin,
        );
      });
    };

    const handleHeightRequest = (event: MessageEvent) => {
      if (
        event.origin === window.location.origin &&
        event.data?.type === adaptiveIframeHeightRequestType
      ) {
        reportHeight();
      }
    };

    const resizeObserver =
      'ResizeObserver' in window ? new ResizeObserver(reportHeight) : undefined;
    if (deliveryRootRef.current) {
      resizeObserver?.observe(deliveryRootRef.current);
    }
    resizeObserver?.observe(document.body);
    resizeObserver?.observe(document.documentElement);
    window.addEventListener('load', reportHeight);
    window.addEventListener('resize', reportHeight);
    window.addEventListener('message', handleHeightRequest);

    reportHeight();

    return () => {
      resizeObserver?.disconnect();
      window.removeEventListener('load', reportHeight);
      window.removeEventListener('resize', reportHeight);
      window.removeEventListener('message', handleHeightRequest);

      if (animationFrame) {
        window.cancelAnimationFrame(animationFrame);
      }
    };
  }, [shouldReportAdaptiveIframeHeight]);

  // this is something SS does.....
  const { width: windowWidth } = useWindowSize();
  const isLessonEnded = useSelector(selectLessonEnd);
  const showRestartDialog = restartLesson && (!reviewMode || (!graded && !previewMode));
  return (
    <div
      ref={deliveryRootRef}
      data-adaptive-delivery-root
      data-adaptive-responsive-layout={String(!!content?.custom?.responsiveLayout)}
      className={`${parentDivClasses.join(' ')} ${currentTheme} ${
        reviewMode && isInstructor ? 'instructor-preview' : ''
      }`}
    >
      <AdaptiveDialogueBridge
        activityAttemptGuid={currentActivityAttemptGuid}
        enabled={adaptiveDialogueBridgeEnabled}
      />
      {!insightsStageOnlyPreview &&
        (previewMode || (reviewMode && (isInstructor || isAdmin || isAuthor))) && (
          <PreviewTools
            reviewMode={reviewMode}
            isInstructor={isInstructor}
            model={content?.model}
          />
        )}
      <div className="mainView" role="main" style={{ width: windowWidth }}>
        <LayoutView pageTitle={pageTitle} previewMode={previewMode} pageContent={content} />
      </div>
      {showRestartDialog ? <RestartLessonDialog onRestart={setInitialPageState} /> : null}
      {isLessonEnded && !reviewMode ? (
        <LessonFinishedDialog
          imageUrl={dialogImageUrl}
          message={dialogMessage}
          hideCloseButton={hideLessonFinishedCloseButton}
        />
      ) : null}
      <DeadlineTimer deadline={localDeadline} lateSubmit={lateSubmit} overviewURL={overviewURL} />
      {screenIdleTimeOutTriggered ? (
        <ScreenIdleTimeOutDialog remainingTime={5} signoutUrl={signoutUrl} />
      ) : null}
    </div>
  );
};

export default Delivery;
