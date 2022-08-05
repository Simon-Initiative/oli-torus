import { configureStore } from 'state/store';
import React, { useEffect, useState } from 'react';
import { OliEmbeddedModelSchema } from 'components/activities/oli_embedded/schema';
import ReactDOM from 'react-dom';
import { Provider, useDispatch } from 'react-redux';
import * as ActivityTypes from 'components/activities/types';
import { DeliveryElement, DeliveryElementProps } from 'components/activities/DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import {
  activityDeliverySlice,
  listenForParentSurveySubmit,
  listenForParentSurveyReset,
} from 'data/activities/DeliveryState';

interface Context {
  attempt_guid: string;
  src_url: string;
  activity_type: string;
  server_url: string;
  user_guid: string;
  mode: string;
  part_ids: string;
}

const EmbeddedDelivery = (_props: DeliveryElementProps<OliEmbeddedModelSchema>) => {
  const {
    state: activityState,
    surveyId,
    onSubmitActivity,
    onResetActivity,
  } = useDeliveryElementContext<OliEmbeddedModelSchema>();

  const [context, setContext] = useState<Context>();
  const [preview, setPreview] = useState<boolean>(false);

  const dispatch = useDispatch();
  useEffect(() => {
    listenForParentSurveySubmit(surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(surveyId, dispatch, onResetActivity);

    fetchContext();
    setInterval(() => {
      const iframe: HTMLIFrameElement = document.querySelector(
        '[data-activityguid="' + activityState.attemptGuid + '"]',
      ) as HTMLIFrameElement;
      if (iframe) {
        const htmlElement = iframe.contentWindow?.document?.querySelector('html');
        if (htmlElement) {
          htmlElement.style.height = '';
        }
        const frameHeight = iframe.contentDocument?.body?.scrollHeight + 'px';
        if (frameHeight) {
          iframe.style.height = frameHeight;
          const htmlElement = iframe.contentWindow?.document?.querySelector('html');
          if (htmlElement) {
            htmlElement.style.height = frameHeight;
          }
        }
      }
    }, 1000);
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
          // height="700"
          frameBorder={0}
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
        ></iframe>
      )}
      {preview && <h4>OLI Embedded activity does not yet support preview</h4>}
    </>
  );
};

export class OliEmbeddedDelivery extends DeliveryElement<OliEmbeddedModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<OliEmbeddedModelSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer);
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
