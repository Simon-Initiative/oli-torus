/* eslint-disable react/prop-types */
import useWindowSize from 'components/hooks/useWindowSize';
import React, { useEffect } from 'react';
import { Provider, useDispatch, useSelector } from 'react-redux';
import PreviewTools from './components/PreviewTools';
import DeckLayoutView from './layouts/deck/DeckLayoutView';
import LessonFinishedDialog from './layouts/deck/LessonFinishedDialog';
import RestartLessonDialog from './layouts/deck/RestartLessonDialog';
import store from './store';
import { selectLessonEnd, selectRestartLesson } from './store/features/adaptivity/slice';
import { LayoutType, selectCurrentGroup } from './store/features/groups/slice';
import { loadInitialPageState } from './store/features/page/actions/loadInitialPageState';
const Delivery = ({ userId, userName, resourceId, sectionSlug, pageTitle = '', pageSlug, content, resourceAttemptGuid, resourceAttemptState, activityGuidMapping, activityTypes = [], previewMode = false, enableHistory = false, graded = false, }) => {
    var _a, _b, _c, _d;
    const dispatch = useDispatch();
    const currentGroup = useSelector(selectCurrentGroup);
    const restartLesson = useSelector(selectRestartLesson);
    let LayoutView = () => <div>Unknown Layout</div>;
    if ((currentGroup === null || currentGroup === void 0 ? void 0 : currentGroup.layout) === LayoutType.DECK) {
        LayoutView = DeckLayoutView;
    }
    useEffect(() => {
        setInitialPageState();
    }, []);
    const setInitialPageState = () => {
        dispatch(loadInitialPageState({
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
        }));
    };
    const parentDivClasses = [];
    if ((_a = content === null || content === void 0 ? void 0 : content.custom) === null || _a === void 0 ? void 0 : _a.viewerSkin) {
        parentDivClasses.push(`skin-${(_b = content === null || content === void 0 ? void 0 : content.custom) === null || _b === void 0 ? void 0 : _b.viewerSkin}`);
    }
    const dialogImageUrl = (_c = content === null || content === void 0 ? void 0 : content.custom) === null || _c === void 0 ? void 0 : _c.logoutPanelImageURL;
    const dialogMessage = (_d = content === null || content === void 0 ? void 0 : content.custom) === null || _d === void 0 ? void 0 : _d.logoutMessage;
    // this is something SS does...
    const { width: windowWidth } = useWindowSize();
    const isLessonEnded = useSelector(selectLessonEnd);
    return (<div className={parentDivClasses.join(' ')}>
      {previewMode && <PreviewTools model={content === null || content === void 0 ? void 0 : content.model}/>}
      <div className="mainView" role="main" style={{ width: windowWidth }}>
        <LayoutView pageTitle={pageTitle} previewMode={previewMode} pageContent={content}/>
      </div>
      {restartLesson ? <RestartLessonDialog onRestart={setInitialPageState}/> : null}
      {isLessonEnded ? (<LessonFinishedDialog imageUrl={dialogImageUrl} message={dialogMessage}/>) : null}
    </div>);
};
const ReduxApp = (props) => (<Provider store={store}>
    <Delivery {...props}/>
  </Provider>);
export default ReduxApp;
//# sourceMappingURL=Delivery.jsx.map