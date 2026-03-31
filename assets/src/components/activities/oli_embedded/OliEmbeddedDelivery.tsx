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
  const [preview, setPreview] = useState<boolean>(false);
  const [previewError, setPreviewError] = useState<string | null>(null);
  const [iframeHeight, setIframeHeight] = useState(500);

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
      })
      .catch((error) => {
        console.error(error);
        setPreviewError(
          'Unable to initialize the embedded activity context. Reload the page and try again.',
        );
        setPreview(true);
      });
  };

  const fetchPreviewContext = () => {
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
      })
      .catch((error) => {
        console.error(error);
        setPreviewError(
          'Unable to initialize embedded preview. Retry the preview, or reload the page and try again.',
        );
        setPreview(true);
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

  return (
    <>
      {previewError ? (
        <div className="alert alert-warning" role="alert">
          {previewError}
        </div>
      ) : null}
      {context && (
        <iframe
          id={activityState.attemptGuid}
          src={context.src_url}
          width="100%"
          style={{ resize: 'vertical', border: 'none' }}
          height={iframeHeight}
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
      )}
      {preview && !context && !previewError && (
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
