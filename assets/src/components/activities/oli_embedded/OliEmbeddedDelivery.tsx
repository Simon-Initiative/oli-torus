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
  } = useDeliveryElementContext<OliEmbeddedModelSchema>();

  const [context, setContext] = useState<Context>();
  const [preview, setPreview] = useState<boolean>(false);
  const [iframeHeight, setIframeHeight] = useState(0);

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

    fetchContext();
  }, []);

  const fetchContext = () => {
    fetch('/jcourse/superactivity/context/' + activityState.attemptGuid, {
      method: 'GET',
    })
      .then((response) => response.json())
      .then((json) => {
        configDefaults(json);
        setContext(json);
      })
      .catch((error) => {
        // :TODO: display error somehow
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
      contextGuid: activityState.attemptGuid,
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
          data-activitycontextguid={activityState.attemptGuid}
          data-activityguid={activityState.attemptGuid}
          data-userguid={context.user_guid}
          data-partids={context.part_ids}
          data-mode="oli"
          onLoad={(event: any) => {
            const { contentWindow, contentDocument } = event.target;
            const embed = contentWindow.document.body.querySelector('#oli-embed');

            // Observe any size changes in the content and update the iframe height
            const resizeObserver = new ResizeObserver((entries) => {
              // This limit to 700px prevents uncontrolled iframe height growth.
              // A bug where for some content layouts settings the iframe height results in a run away height growth loop
              if (contentDocument.body.scrollHeight < 700) {
                setIframeHeight(contentDocument.body.scrollHeight);
              }
            });

            resizeObserver.observe(embed);
          }}
        ></iframe>
      )}
      {preview && <h4>OLI Embedded activity does not yet support preview</h4>}
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
