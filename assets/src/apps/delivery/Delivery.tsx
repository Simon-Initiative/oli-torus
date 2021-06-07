/* eslint-disable react/prop-types */
import useWindowSize from 'components/hooks/useWindowSize';
import React, { useEffect } from 'react';
import { Provider, useDispatch, useSelector } from 'react-redux';
import PreviewTools from './components/PreviewTools';
import DeckLayoutView from './layouts/deck/DeckLayoutView';
import LessonFinishedDialogProps from './layouts/deck/LessonFinishedDialog';
import { LayoutProps } from './layouts/layouts';
import store from './store';
import { selectLessonEnd } from './store/features/adaptivity/slice';
import { LayoutType, selectCurrentGroup } from './store/features/groups/slice';
import { loadInitialPageState } from './store/features/page/actions/loadInitialPageState';
import { selectRestartLesson } from './store/features/adaptivity/slice';
import RestartLessonDialog from './layouts/deck/RestartLessonDialog';

export interface DeliveryProps {
  resourceId: number;
  sectionSlug: string;
  userId: number;
  pageTitle: string;
  pageSlug: string;
  content: any;
  resourceAttemptState: any;
  resourceAttemptGuid: string;
  activityGuidMapping: any;
  previewMode?: boolean;
  activityTypes?: any[];
}

const Delivery: React.FC<DeliveryProps> = ({
  userId,
  resourceId,
  sectionSlug,
  pageTitle = '',
  pageSlug,
  content,
  resourceAttemptGuid,
  resourceAttemptState,
  activityGuidMapping,
  activityTypes = [],
  previewMode = false,
}) => {
  const dispatch = useDispatch();
  const currentGroup = useSelector(selectCurrentGroup);
  const restartLesson = useSelector(selectRestartLesson);
  let LayoutView: React.FC<LayoutProps> = () => <div>Unknown Layout</div>;
  if (currentGroup?.layout === LayoutType.DECK) {
    LayoutView = DeckLayoutView;
  }

  useEffect(() => {
    setInitialPageState();
  }, []);

  const setInitialPageState = () => {
    dispatch(
      loadInitialPageState({
        userId,
        resourceId,
        sectionSlug,
        pageTitle,
        pageSlug,
        content,
        resourceAttemptGuid,
        resourceAttemptState,
        activityGuidMapping,
        previewMode: !!previewMode,
        activityTypes,
      }),
    );
  }
  const parentDivClasses: string[] = [];
  if (content?.custom?.viewerSkin) {
    parentDivClasses.push(`skin-${content?.custom?.viewerSkin}`);
  }
  const dialogImageUrl = content?.custom?.logoutPanelImageURL;
  const dialogMessage = content?.custom?.logoutMessage;
  // this is something SS does...
  const { width: windowWidth } = useWindowSize();
  const isLessonEnded = useSelector(selectLessonEnd);
  return (
    <div className={parentDivClasses.join(' ')}>
      {previewMode && <PreviewTools model={content?.model} />}
      <div className="mainView" role="main" style={{ width: windowWidth }}>
        <LayoutView pageTitle={pageTitle} previewMode={previewMode} pageContent={content} />
      </div>
      {restartLesson ? (
            <RestartLessonDialog onRestart={setInitialPageState} />
        ) : null}
      {isLessonEnded ? (
        <LessonFinishedDialogProps imageUrl={dialogImageUrl} message={dialogMessage} />
      ) : null}
    </div>
  );
};

const ReduxApp: React.FC<DeliveryProps> = (props) => (
  <Provider store={store}>
    <Delivery {...props} />
  </Provider>
);

export default ReduxApp;
