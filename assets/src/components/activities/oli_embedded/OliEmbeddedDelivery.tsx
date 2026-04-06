import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch } from 'react-redux';
import { DeliveryElement, DeliveryElementProps } from 'components/activities/DeliveryElement';
import { OliEmbeddedModelSchema } from 'components/activities/oli_embedded/schema';
import * as ActivityTypes from 'components/activities/types';
import {
  activityDeliverySlice,
  listenForParentSurveyReset,
  listenForParentSurveySubmit,
  listenForReviewAttemptChange,
} from 'data/activities/DeliveryState';
import { finalizePageAttempt } from 'data/persistence/page_lifecycle';
import { configureStore } from 'state/store';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';

interface Context {
  attempt_guid: string;
  src_url: string;
  activity_type: string;
  server_url: string;
  user_guid: string;
  mode: string;
  part_ids: string;
  auto_finalize_page?: boolean;
  auto_finalize_redirect_url?: string;
  revision_slug?: string;
  section_slug?: string;
  page_attempt_guid?: string;
}

const EmbeddedDelivery = (props: DeliveryElementProps<OliEmbeddedModelSchema>) => {
  const {
    state: activityState,
    model,
    onSubmitActivity,
    onResetActivity,
    context: activityContext,
    mode,
  } = useDeliveryElementContext<OliEmbeddedModelSchema>();

  const [context, setContext] = useState<Context>();
  const [initializing, setInitializing] = useState<boolean>(true);
  const [showLoadingUI, setShowLoadingUI] = useState<boolean>(false);
  const [loadingVisible, setLoadingVisible] = useState<boolean>(false);
  const [iframeReady, setIframeReady] = useState<boolean>(false);
  const [preview, setPreview] = useState<boolean>(false);
  const [previewError, setPreviewError] = useState<string | null>(null);
  const [pageFinalizeError, setPageFinalizeError] = useState<string | null>(null);
  const [iframeHeight, setIframeHeight] = useState(500);
  const reviewMode =
    mode === 'review' ||
    (typeof window !== 'undefined' && window.location.pathname.includes('/review'));

  const dispatch = useDispatch();
  useEffect(() => {
    listenForParentSurveySubmit(activityContext.surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(activityContext.surveyId, dispatch, onResetActivity);
    listenForReviewAttemptChange(
      model,
      activityState.activityId as number,
      dispatch,
      activityContext,
    );

    const parser = new DOMParser();
    const modelDoc = parser.parseFromString(model.modelXml, 'text/xml');
    const modelRootNode = modelDoc.querySelector(':root');
    if (modelRootNode != null) {
      let height = modelRootNode.getAttribute('height');
      if (height) {
        try {
          // Extract number
          height = height.replace(/[^0-9]/g, '');
          setIframeHeight(parseInt(height));
        } catch (error) {
          console.error(error);
        }
      }
    }

    fetchContext();
  }, []);

  const fetchContext = () => {
    setInitializing(true);
    setIframeReady(false);

    if (mode === 'author_preview' || mode === 'preview') {
      fetchPreviewContext();
      return;
    }

    fetch('/jcourse/superactivity/context/' + activityState.attemptGuid, {
      method: 'GET',
    })
      .then((response) => response.json())
      .then((json) => {
        setPreviewError(null);
        configDefaults(json);
        setContext(json);
        setInitializing(false);
      })
      .catch((error) => {
        console.error(error);
        setPreviewError(
          'Unable to initialize the embedded activity context. Reload the page and try again.',
        );
        setPreview(true);
        setInitializing(false);
      });
  };

  const revealSubmitAnswersButton = () => {
    const submitButton = document.getElementById('submit_answers') as HTMLButtonElement | null;

    if (!submitButton) {
      return;
    }

    submitButton.classList.remove('hidden', 'd-none');
    submitButton.disabled = false;
  };

  const fetchPreviewContext = () => {
    setInitializing(true);
    setIframeReady(false);

    fetch('/jcourse/superactivity/preview_context', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        attemptGuid: activityState.attemptGuid,
        model,
        context: activityContext,
      }),
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`Unable to initialize embedded preview: ${response.status}`);
        }

        return response.json();
      })
      .then((json) => {
        setPreviewError(null);
        configDefaults(json);
        setContext(json);
        setInitializing(false);
      })
      .catch((error) => {
        console.error(error);
        setPreviewError(
          'Unable to initialize embedded preview. Retry the preview, or reload the page and try again.',
        );
        setPreview(true);
        setInitializing(false);
      });
  };

  // eslint-disable-next-line @typescript-eslint/ban-ts-comment
  // @ts-ignore
  window.adjustIframeHeight = (i, f) => {
    // No-op. Here for backward compatibility
  };

  const configDefaults = (context: Context) => {
    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-ignore
    window.workbookConfig = {
      userGUID: context.user_guid,
      sessionGuid: '1958e2f50a0000562295c9a569354ab5',
      contextGuid: context.attempt_guid,
      dataSet: 'none',
      syllabusURI: 'none',
      sectionTitle: 'none',
      isGuestSection: false,
      pageContextGuid: 'none',
      pageActivityGuid: 'none',
      wbkContextGuid: 'none',
      wbkActivityGuid: 'none',
      isStandalone: false,
      isSupplement: false,
      enableAuthorWidget: false,
      authToken: 'none',
      logService: '/jcourse/dashboard/log/server',
      courseKey: 'none',
      pageNumber: 1,
      unit: 'some unit',
      unit_nr: 1,
      module: 'some module',
      module_nr: 1,
      section: 'section title',
      userGroup: 'none',
    };

    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-ignore
    window.AZ = {
      d: { courseKey: 'key1', pageNumber: 1 },
    };
  };

  const shouldShowLoadingState = !previewError && (initializing || (!!context && !iframeReady));
  const containerHeight = Math.max(220, iframeHeight);

  useEffect(() => {
    let showTimeoutId: number | undefined;
    let hideTimeoutId: number | undefined;
    let animationFrameId: number | undefined;

    if (shouldShowLoadingState) {
      if (showLoadingUI) {
        setLoadingVisible(true);
      } else {
        showTimeoutId = window.setTimeout(() => {
          setShowLoadingUI(true);
          animationFrameId = window.requestAnimationFrame(() => setLoadingVisible(true));
        }, 150);
      }
    } else if (showLoadingUI) {
      setLoadingVisible(false);
      hideTimeoutId = window.setTimeout(() => setShowLoadingUI(false), 220);
    } else {
      setLoadingVisible(false);
    }

    return () => {
      if (showTimeoutId !== undefined) {
        window.clearTimeout(showTimeoutId);
      }

      if (hideTimeoutId !== undefined) {
        window.clearTimeout(hideTimeoutId);
      }

      if (animationFrameId !== undefined) {
        window.cancelAnimationFrame(animationFrameId);
      }
    };
  }, [shouldShowLoadingState, showLoadingUI]);

  useEffect(() => {
    if (!context) {
      return;
    }

    if (mode === 'author_preview' || mode === 'preview' || mode === 'review') {
      return;
    }

    if (
      !activityContext.graded ||
      !activityContext.batchScoring ||
      activityContext.surveyId !== null
    ) {
      return;
    }

    if (!context.auto_finalize_page) {
      return;
    }

    let cancelled = false;
    let finalizeRequested = false;
    let pendingPoll = false;

    const pollForSubmission = async () => {
      if (cancelled || finalizeRequested || pendingPoll) {
        return;
      }

      pendingPoll = true;

      try {
        const response = await fetch(
          `/api/v1/state/course/${activityContext.sectionSlug}/activity_attempt/${activityState.attemptGuid}`,
          {
            method: 'GET',
            headers: {
              Accept: 'application/json',
            },
          },
        );

        if (!response.ok) {
          return;
        }

        const json = await response.json();
        const attemptState = json?.state;
        const submitted =
          attemptState?.dateEvaluated !== null ||
          attemptState?.dateSubmitted !== null ||
          attemptState?.lifecycle_state === 'evaluated' ||
          attemptState?.lifecycle_state === 'submitted';

        if (!submitted) {
          return;
        }

        finalizeRequested = true;
        setPageFinalizeError(null);

        if (context.section_slug && context.revision_slug && context.page_attempt_guid) {
          const finalizeResult = await finalizePageAttempt(
            context.section_slug,
            context.revision_slug,
            context.page_attempt_guid,
          );

          if (
            'redirectTo' in finalizeResult &&
            typeof finalizeResult.redirectTo === 'string' &&
            finalizeResult.redirectTo.length > 0
          ) {
            window.location.href = finalizeResult.redirectTo;
            return;
          }
        }

        if (context.auto_finalize_redirect_url) {
          window.location.href = context.auto_finalize_redirect_url;
          return;
        }

        finalizeRequested = false;
        revealSubmitAnswersButton();
        setPageFinalizeError(
          'Embedded activity submission completed, but automatic page redirect was unavailable. Use Submit Answers to finish the page.',
        );
      } catch (error) {
        console.error(error);
      } finally {
        pendingPoll = false;
      }
    };

    const intervalId = window.setInterval(pollForSubmission, 1500);
    void pollForSubmission();

    return () => {
      cancelled = true;
      window.clearInterval(intervalId);
    };
  }, [
    activityContext.batchScoring,
    activityContext.graded,
    activityContext.pageAttemptGuid,
    activityContext.sectionSlug,
    activityContext.surveyId,
    activityState.attemptGuid,
    context,
    mode,
  ]);

  return (
    <>
      {previewError ? (
        <div className="alert alert-warning" role="alert">
          {previewError}
        </div>
      ) : null}
      {pageFinalizeError ? (
        <div className="alert alert-warning" role="alert">
          {pageFinalizeError}
        </div>
      ) : null}
      {(context || showLoadingUI) && (
        <div
          style={{
            position: 'relative',
            width: '100%',
            height: `${containerHeight}px`,
            overflow: 'hidden',
          }}
        >
          {context ? (
            <iframe
              id={activityState.attemptGuid}
              src={context.src_url}
              width="100%"
              style={{
                display: 'block',
                resize: 'vertical',
                border: 'none',
                height: `${iframeHeight}px`,
                pointerEvents: reviewMode ? 'none' : 'auto',
                opacity: iframeReady ? 1 : 0,
                transition: 'opacity 220ms ease-out',
              }}
              height={iframeHeight}
              tabIndex={reviewMode ? -1 : undefined}
              onLoad={() => {
                setIframeReady(true);
                setInitializing(false);
              }}
              data-authenticationtoken="none"
              data-sessionid="1958e2f50a0000562295c9a569354ab5"
              data-resourcetypeid={context.activity_type}
              data-superactivityserver={context.server_url}
              data-activitymode={context.mode}
              allowFullScreen={true}
              data-activitycontextguid={context.attempt_guid}
              data-activityguid={context.attempt_guid}
              data-userguid={context.user_guid}
              data-partids={context.part_ids}
              data-mode="oli"
            ></iframe>
          ) : null}
          {reviewMode && context ? (
            <div
              aria-hidden="true"
              style={{
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                zIndex: 2,
                cursor: 'not-allowed',
                background: 'transparent',
                pointerEvents: 'auto',
              }}
            ></div>
          ) : null}
          {showLoadingUI ? (
            <div
              className="d-flex flex-column align-items-center justify-content-center text-center rounded border bg-light"
              style={{
                position: context ? 'absolute' : 'relative',
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                padding: '1.5rem',
                opacity: loadingVisible ? 1 : 0,
                transition: 'opacity 220ms ease-out',
                pointerEvents: loadingVisible ? 'auto' : 'none',
              }}
              role="status"
              aria-live="polite"
              aria-busy="true"
            >
              <div className="spinner-border text-primary mb-3" aria-hidden="true"></div>
              <div className="fw-semibold mb-1">Loading embedded activity</div>
              <div className="text-muted small">
                Preparing the runtime and loading activity assets for this preview.
              </div>
            </div>
          ) : null}
        </div>
      )}
      {preview && !context && !previewError && !initializing && !showLoadingUI && (
        <h4>OLI Embedded activity does not yet support preview</h4>
      )}
    </>
  );
};

export class OliEmbeddedDelivery extends DeliveryElement<OliEmbeddedModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<OliEmbeddedModelSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer, {
      name: 'OLIEmbeddedDelivery',
    });
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <EmbeddedDelivery {...props} />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, OliEmbeddedDelivery);
