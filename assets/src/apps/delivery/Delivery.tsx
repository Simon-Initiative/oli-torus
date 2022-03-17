import { janus_std } from 'adaptivity/janus-scripts/builtin_functions';
import { defaultGlobalEnv, evalScript } from 'adaptivity/scripting';
import useWindowSize from 'components/hooks/useWindowSize';
import React, { useEffect } from 'react';
import { Provider, useDispatch, useSelector } from 'react-redux';
import PreviewTools from './components/PreviewTools';
import DeckLayoutView from './layouts/deck/DeckLayoutView';
import LessonFinishedDialog from './layouts/deck/LessonFinishedDialog';
import RestartLessonDialog from './layouts/deck/RestartLessonDialog';
import { LayoutProps } from './layouts/layouts';
import store from './store';
import { selectLessonEnd, selectRestartLesson } from './store/features/adaptivity/slice';
import { LayoutType, selectCurrentGroup } from './store/features/groups/slice';
import { loadInitialPageState } from './store/features/page/actions/loadInitialPageState';

export interface DeliveryProps {
  resourceId: number;
  sectionSlug: string;
  userId: number;
  userName: string;
  pageTitle: string;
  pageSlug: string;
  content: any;
  resourceAttemptState: any;
  resourceAttemptGuid: string;
  activityGuidMapping: any;
  previewMode?: boolean;
  enableHistory?: boolean;
  activityTypes?: any[];
  graded: boolean;
}

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
  activityGuidMapping,
  activityTypes = [],
  previewMode = false,
  enableHistory = false,
  graded = false,
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
        activityGuidMapping,
        previewMode: !!previewMode,
        activityTypes,
        enableHistory,
        showHistory: false,
        score: 0,
        graded,
        activeEverapp: 'none',
      }),
    );
  };
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
      {restartLesson ? <RestartLessonDialog onRestart={setInitialPageState} /> : null}
      {isLessonEnded ? (
        <LessonFinishedDialog imageUrl={dialogImageUrl} message={dialogMessage} />
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
