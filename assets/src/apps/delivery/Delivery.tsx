/* eslint-disable react/prop-types */
import useWindowSize from 'components/hooks/useWindowSize';
import React, { useEffect } from 'react';
import { Provider } from 'react-redux';
import AdaptivePageView from './formats/adaptive/AdaptivePageView';
import DeckLayoutView from './layouts/deck/DeckLayoutView';
import { LayoutProps } from './layouts/layouts';
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

export const Delivery: React.FunctionComponent<DeliveryProps> = ({
  userId,
  resourceId,
  sectionSlug,
  pageSlug,
  content,
  resourceAttemptGuid,
  resourceAttemptState,
  activityGuidMapping,
  previewMode = false,
}) => {
  let LayoutView: React.FC<LayoutProps> = () => <div>Unknown Layout</div>;
  const [firstChild] = content.model;
  // TODO: if first child is a activity-reference maybe do a "SingleLayoutView"?
  // but for now use this "old" one
  if (firstChild.type === 'activity-reference') {
    LayoutView = AdaptivePageView;
  }
  if (firstChild.type === 'group') {
    // TODO: maybe a map of layouts or something else,
    // but this is the only one for now
    if (firstChild.layout === 'deck') {
      LayoutView = DeckLayoutView;
    }
  }

  useEffect(() => {
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
  if (content?.custom?.viewerSkin) {
    parentDivClasses.push(`skin-${content?.custom?.viewerSkin}`);
  }

  // this is something SS does...
  const { width: windowWidth } = useWindowSize();

  return (
    <Provider store={store}>
      <div className={parentDivClasses.join(' ')}>
        <div className="mainView" role="main" style={{ width: windowWidth }}>
          <LayoutView previewMode={previewMode} pageContent={content} />
        </div>
      </div>
    </Provider>
  );
};
