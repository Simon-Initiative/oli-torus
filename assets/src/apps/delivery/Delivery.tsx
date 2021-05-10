import useWindowSize from 'components/hooks/useWindowSize';
import React, { useEffect } from 'react';
import { Provider } from 'react-redux';
import AdaptivePageView from './formats/adaptive/AdaptivePageView';
import store from './store';
import { loadActivities, loadActivityState } from './store/features/activities/slice';
import { loadPageState } from './store/features/page/slice';

export interface DeliveryProps {
  resourceId: number;
  sectionSlug: string;
  userId: number;
  pageSlug: string;
  content: any;
  resourceAttemptState: any;
  resourceAttemptGuid: string;
  activityGuidMapping: any;
  previewMode?: boolean;
}

export const Delivery: React.FunctionComponent<DeliveryProps> = (props: DeliveryProps) => {
  useEffect(() => {
    const {
      userId,
      resourceId,
      sectionSlug,
      pageSlug,
      content,
      resourceAttemptGuid,
      resourceAttemptState,
      activityGuidMapping,
      previewMode,
    } = props;

    store.dispatch(
      loadPageState({
        userId,
        resourceId,
        sectionSlug,
        pageSlug,
        content,
        resourceAttemptGuid,
        resourceAttemptState,
        activityGuidMapping,
        previewMode: !!previewMode,
      }),
    );

    // for the moment load *all* the activity state
    if (!previewMode && !!activityGuidMapping) {
      const attemptGuids = Object.keys(activityGuidMapping).map((activityResourceId) => {
        const { attemptGuid } = activityGuidMapping[activityResourceId];
        return attemptGuid;
      });
      store.dispatch(loadActivityState(attemptGuids));
    }

    if (previewMode) {
      let activityIds;
      const [rootContainer] = content.model;
      if (rootContainer.type === 'group') {
        activityIds = rootContainer.children.map((child: any) => child.activity_id);
      } else {
        activityIds = content.model.map((child: any) => child.activity_id);
      }
      store.dispatch(loadActivities(activityIds));
    }
  }, []);

  const parentDivClasses: string[] = [];
  if (props.content?.custom?.viewerSkin) {
    parentDivClasses.push(`skin-${props.content?.custom?.viewerSkin}`);
  }

  // this is something SS does...
  const { width: windowWidth } = useWindowSize();

  return (
    <Provider store={store}>
      <div className={parentDivClasses.join(' ')}>
        <div className="mainView" role="main" style={{ width: windowWidth }}>
          <AdaptivePageView />
        </div>
      </div>
    </Provider>
  );
};
