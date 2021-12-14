var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
/* eslint-disable react/prop-types */
import chroma from 'chroma-js';
import React, { useCallback, useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { bulkApplyState, defaultGlobalEnv, evalScript, getEnvState, getLocalizedStateSnapshot, getValue, removeStateValues, } from '../../../../adaptivity/scripting';
import { contexts } from '../../../../types/applicationContext';
import ActivityRenderer from '../../components/ActivityRenderer';
import { triggerCheck } from '../../store/features/adaptivity/actions/triggerCheck';
import { selectHistoryNavigationActivity, selectLessonEnd, setInitPhaseComplete, } from '../../store/features/adaptivity/slice';
import { savePartState, savePartStateToTree } from '../../store/features/attempt/actions/savePart';
import { initializeActivity } from '../../store/features/groups/actions/deck';
import { selectCurrentActivityTree, selectCurrentActivityTreeAttemptState, } from '../../store/features/groups/selectors/deck';
import { selectEnableHistory, selectUserName, setScore } from '../../store/features/page/slice';
import DeckLayoutFooter from './DeckLayoutFooter';
import DeckLayoutHeader from './DeckLayoutHeader';
import { getLocalizedCurrentStateSnapshot } from 'apps/delivery/store/features/adaptivity/actions/getLocalizedCurrentStateSnapshot';
const InjectedStyles = (props) => {
    // migrated legacy include as customCss
    // BS: do we need a default?
    const defaultCss = '';
    const injected = props.css || defaultCss;
    return injected ? <style>{injected}</style> : null;
};
const sharedActivityInit = new Map();
let sharedActivityPromise;
const DeckLayoutView = ({ pageTitle, pageContent, previewMode }) => {
    var _a, _b, _c;
    const dispatch = useDispatch();
    const fieldRef = React.useRef(null);
    const currentActivityTree = useSelector(selectCurrentActivityTree);
    const currentActivityAttemptTree = useSelector(selectCurrentActivityTreeAttemptState);
    const currentUserName = useSelector(selectUserName);
    const historyModeNavigation = useSelector(selectHistoryNavigationActivity);
    const isEnd = useSelector(selectLessonEnd);
    const defaultClasses = ['lesson-loaded', previewMode ? 'previewView' : 'lessonView'];
    const [pageClasses, setPageClasses] = useState([]);
    const [activityClasses, setActivityClasses] = useState([...defaultClasses]);
    const [lessonStyles, setLessonStyles] = useState({});
    const enableHistory = useSelector(selectEnableHistory);
    // Background
    const backgroundClasses = ['background'];
    const backgroundStyles = {};
    if ((_a = pageContent === null || pageContent === void 0 ? void 0 : pageContent.custom) === null || _a === void 0 ? void 0 : _a.backgroundImageURL) {
        backgroundStyles.backgroundImage = `url('${pageContent.custom.backgroundImageURL}')`;
    }
    if ((_b = pageContent === null || pageContent === void 0 ? void 0 : pageContent.custom) === null || _b === void 0 ? void 0 : _b.backgroundImageScaleContent) {
        backgroundClasses.push('background-scaled');
    }
    const getCustomClassAncestry = () => {
        let className = '';
        if (currentActivityTree) {
            currentActivityTree.forEach((activity) => {
                var _a, _b, _c, _d;
                if ((_b = (_a = activity === null || activity === void 0 ? void 0 : activity.content) === null || _a === void 0 ? void 0 : _a.custom) === null || _b === void 0 ? void 0 : _b.customCssClass) {
                    className += (_d = (_c = activity === null || activity === void 0 ? void 0 : activity.content) === null || _c === void 0 ? void 0 : _c.custom) === null || _d === void 0 ? void 0 : _d.customCssClass;
                }
            });
        }
        return className;
    };
    useEffect(() => {
        // clear body classes on init for a clean slate
        document.body.className = '';
    }, []);
    useEffect(() => {
        var _a, _b;
        if (!pageContent) {
            return;
        }
        // set page class on change
        if ((_a = pageContent === null || pageContent === void 0 ? void 0 : pageContent.custom) === null || _a === void 0 ? void 0 : _a.viewerSkin) {
            setPageClasses([`skin-${pageContent.custom.viewerSkin}`]);
        }
        const lessonWidth = pageContent.custom.defaultScreenWidth || '100%';
        const lessonHeight = pageContent.custom.defaultScreenHeight;
        // TODO: add a flag to lesson data use the height?
        const useLessonHeight = false;
        setLessonStyles(() => {
            const styles = {
                width: lessonWidth,
            };
            if (useLessonHeight) {
                styles.height = lessonHeight;
            }
            return styles;
        });
        if (pageContent === null || pageContent === void 0 ? void 0 : pageContent.customScript) {
            // apply a custom *janus* script if defined
            // this is for user defined functions (also legacy)
            // TODO: something if there are errors
            const csResult = evalScript(pageContent === null || pageContent === void 0 ? void 0 : pageContent.customScript, defaultGlobalEnv);
            /* console.log('Lesson Custom Script: ', {
              script: pageContent?.customScript,
              csResult,
            }); */
        }
        if (Array.isArray((_b = pageContent === null || pageContent === void 0 ? void 0 : pageContent.custom) === null || _b === void 0 ? void 0 : _b.variables)) {
            const allNames = pageContent.custom.variables.map((v) => v.name);
            // variables can and will ref previous ones
            // they will reference them "globally" so need to track the above
            // in order to prepend the "variables" namespace
            const statements = pageContent.custom.variables
                .map((v) => {
                if (!v.name || !v.expression) {
                    return '';
                }
                let expr = v.expression;
                allNames.forEach((name) => {
                    const regex = new RegExp(`{${name}}`, 'g');
                    expr = expr.replace(regex, `{variables.${name}}`);
                });
                const stmt = `let {variables.${v.name.trim()}} = ${expr};`;
                return stmt;
            })
                .filter((s) => s);
            // execute each sequentially in case there are errors (missing functions)
            statements.forEach((statement) => {
                evalScript(statement, defaultGlobalEnv);
            });
        }
    }, [pageContent]);
    useEffect(() => {
        var _a, _b, _c, _d, _e;
        if (!currentActivityTree || currentActivityTree.length === 0) {
            return;
        }
        // Need to clear out snapshot for the current activity before we send the init trap state.
        // this is needed for use cases where, when we re-visit an activity screen, it needs to restart fresh otherwise
        // some screens go in loop
        // Don't do anything id enableHistory/historyModeNavigation is ON
        if (!historyModeNavigation && currentActivityTree) {
            const globalSnapshot = getEnvState(defaultGlobalEnv);
            // this is firing after some initial part saves and wiping out what we have just set
            // maybe we don't need to write the local versions ever?? instead just whenever anything
            // is asking for it we can just give the localized snapshot?
            const currentActivity = currentActivityTree[currentActivityTree.length - 1];
            const idsToBeRemoved = Object.keys(globalSnapshot).filter((key) => key.indexOf('stage.') === 0 || key.indexOf(`${currentActivity.id}|stage.`) === 0); /*
            console.log('REMOVING STATE VALUES: ', idsToBeRemoved); */
            if (idsToBeRemoved.length) {
                removeStateValues(defaultGlobalEnv, idsToBeRemoved);
            }
        }
        let timeout;
        let resolve;
        let reject;
        const promise = new Promise((res, rej) => {
            let resolved = false;
            resolve = (value) => {
                resolved = true;
                res(value);
            };
            reject = (reason) => {
                resolved = true;
                rej(reason);
            };
            timeout = setTimeout(() => {
                if (resolved) {
                    return;
                }
                console.error('[AllActivitiesInit] failed to resolve within time limit', {
                    currentActivityTree,
                    timeout,
                });
            }, 10000);
        });
        sharedActivityPromise = { promise, resolve, reject };
        currentActivityTree.forEach((activity) => {
            // layers already might be there
            // TODO: do I need to reset ever???
            if (!sharedActivityInit.has(activity.id)) {
                sharedActivityInit.set(activity.id, false);
            }
        });
        const currentActivity = currentActivityTree[currentActivityTree.length - 1];
        if (!currentActivity) {
            return;
        }
        // set loaded and userRole class when currentActivity is loaded
        let customClasses = ((_b = (_a = currentActivity.content) === null || _a === void 0 ? void 0 : _a.custom) === null || _b === void 0 ? void 0 : _b.customCssClass) || '';
        if (currentActivityTree.length) {
            customClasses = `${customClasses} ${getCustomClassAncestry()}`;
        }
        setActivityClasses([...defaultClasses, customClasses]);
        if (fieldRef.current) {
            fieldRef.current.scrollIntoView();
        }
        if ((_c = currentActivity === null || currentActivity === void 0 ? void 0 : currentActivity.custom) === null || _c === void 0 ? void 0 : _c.customCssClass) {
            // split space delimited strings into array of strings
            const customClasses = ((_e = (_d = currentActivity.content) === null || _d === void 0 ? void 0 : _d.customCssClass) === null || _e === void 0 ? void 0 : _e.split(' ')) || [];
            customClasses.map((c) => {
                if (c === 'defaultFeedback') {
                    setPageClasses([...new Set([...pageClasses, c])]);
                }
            });
            // set new class list after check for duplicate strings
            // & strip whitespace from array strings
            setActivityClasses([...new Set([...defaultClasses, ...customClasses])].map((str) => str.trim()));
        }
        return () => {
            clearTimeout(timeout);
            sharedActivityPromise = null;
        };
    }, [currentActivityTree]);
    useEffect(() => {
        // clear the body classes in prep for the real classes
        document.body.className = '';
        // strip whitespace and update body class list with page classes
        document.body.classList.add(...pageClasses);
    }, [pageClasses]);
    const initCurrentActivity = useCallback(() => __awaiter(void 0, void 0, void 0, function* () {
        if (!currentActivityTree) {
            console.error('[initCurrentActivity] no currentActivityTree');
            return;
        }
        const currentActivity = currentActivityTree[currentActivityTree.length - 1];
        if (!currentActivity) {
            console.error('[initCurrentActivity] bad tree??', currentActivityTree);
            return;
        }
        yield dispatch(initializeActivity(currentActivity.resourceId));
    }), [currentActivityTree]);
    const handleActivityReady = (activityId, attemptGuid) => __awaiter(void 0, void 0, void 0, function* () {
        sharedActivityInit.set(activityId, true);
        // BS: this is init state phase (mostly) and it needs to run AFTER every part
        // has already saved its "default" values or else the init state rules will just
        // get overwritten by them saving the default value
        //
        /* console.log('DECK HANDLE READY', {
          activityId,
          attemptGuid,
          currentActivityTree,
          sharedActivityInit: Array.from(sharedActivityInit.entries()),
        }); */
        if (currentActivityTree === null || currentActivityTree === void 0 ? void 0 : currentActivityTree.every((activity) => sharedActivityInit.get(activity.id) === true)) {
            yield initCurrentActivity();
            const currentActivityIds = (currentActivityTree || []).map((a) => a.id);
            sharedActivityPromise.resolve({
                snapshot: getLocalizedStateSnapshot(currentActivityIds),
                context: {
                    currentActivity: currentActivityTree[currentActivityTree.length - 1].id,
                    mode: historyModeNavigation ? contexts.REVIEW : contexts.VIEWER,
                },
            });
            dispatch(setInitPhaseComplete(true));
        }
        return sharedActivityPromise.promise;
    });
    const handleActivitySave = (activityId, attemptGuid, partResponses) => __awaiter(void 0, void 0, void 0, function* () {
        /* console.log('DECK HANDLE SAVE', { activityId, attemptGuid, partResponses }); */
        // TODO: currently not used.
        return true;
    });
    const handleActivitySubmit = (activityId, attemptGuid, partResponses) => __awaiter(void 0, void 0, void 0, function* () {
        /* console.log('DECK HANDLE SUBMIT', { activityId, attemptGuid, partResponses }); */
        // TODO: currently not used.
        return true;
    });
    const handleActivitySavePart = (activityId, attemptGuid, partAttemptGuid, response) => __awaiter(void 0, void 0, void 0, function* () {
        var _d;
        /* console.log('DECK HANDLE SAVE PART', {
          activityId,
          attemptGuid,
          partAttemptGuid,
          response,
          currentActivityTree,
        }); */
        const statePrefix = `${activityId}|stage`;
        const responseMap = response.input.reduce((result, item) => {
            result[item.key] = Object.assign(Object.assign({}, item), { path: `${statePrefix}.${item.path}` });
            return result;
        }, {});
        const currentActivityIds = (currentActivityTree || []).map((a) => a.id);
        if (!currentActivityTree || !currentActivityTree.length) {
            // throw instead?
            return { result: 'error' };
        }
        //if user navigated from history, don't save anything and just return the saved state
        if (historyModeNavigation) {
            return { result: null, snapshot: getLocalizedStateSnapshot(currentActivityIds) };
        }
        if ((_d = response === null || response === void 0 ? void 0 : response.input) === null || _d === void 0 ? void 0 : _d.length) {
            let result;
            // in addition to the current part attempt, need to lookup in the tree
            // if this part is an inherited part and also write to the child attempt records
            const currentActivity = currentActivityTree[currentActivityTree.length - 1];
            if (currentActivity.id !== activityId) {
                // this means that the part is inherted (we are a layer or parent screen)
                // so we need to update all children in the tree with this part response as well
                result = yield dispatch(savePartStateToTree({
                    attemptGuid,
                    partAttemptGuid,
                    response: responseMap,
                    activityTree: currentActivityTree,
                }));
            }
            else {
                result = yield dispatch(savePartState({ attemptGuid, partAttemptGuid, response: responseMap }));
            }
            return { result, snapshot: getLocalizedStateSnapshot(currentActivityIds) };
        }
        else {
            return { result: null, snapshot: getLocalizedStateSnapshot(currentActivityIds) };
        }
    });
    const handleActivitySubmitPart = (activityId, attemptGuid, partAttemptGuid, response) => __awaiter(void 0, void 0, void 0, function* () {
        // save before submitting
        const { result, snapshot } = yield handleActivitySavePart(activityId, attemptGuid, partAttemptGuid, response);
        dispatch(triggerCheck({ activityId: activityId.toString() }));
        return { result, snapshot };
    });
    const handleActivityRequestLatestState = useCallback(() => __awaiter(void 0, void 0, void 0, function* () {
        const sResult = yield dispatch(getLocalizedCurrentStateSnapshot());
        const { payload: { snapshot }, } = sResult;
        return {
            snapshot,
        };
    }), [currentActivityTree]);
    const renderActivities = useCallback(() => {
        var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
        if (!currentActivityTree || !currentActivityTree.length) {
            return <div>loading...</div>;
        }
        const actualCurrentActivity = currentActivityTree[currentActivityTree.length - 1];
        const config = actualCurrentActivity.content.custom;
        const styles = {
            width: (config === null || config === void 0 ? void 0 : config.width) || lessonStyles.width,
        };
        if (config === null || config === void 0 ? void 0 : config.palette) {
            if (config.palette.useHtmlProps) {
                styles.backgroundColor = config.palette.backgroundColor;
                styles.borderColor = config.palette.borderColor;
                styles.borderWidth = config.palette.borderWidth;
                styles.borderStyle = config.palette.borderStyle;
                styles.borderRadius = config.palette.borderRadius;
            }
            else {
                styles.borderWidth = `${((_a = config === null || config === void 0 ? void 0 : config.palette) === null || _a === void 0 ? void 0 : _a.lineThickness) ? ((_b = config === null || config === void 0 ? void 0 : config.palette) === null || _b === void 0 ? void 0 : _b.lineThickness) + 'px' : '1px'}`;
                styles.borderRadius = '10px';
                styles.borderStyle = 'solid';
                styles.borderColor = `rgba(${((_c = config === null || config === void 0 ? void 0 : config.palette) === null || _c === void 0 ? void 0 : _c.lineColor) || ((_d = config === null || config === void 0 ? void 0 : config.palette) === null || _d === void 0 ? void 0 : _d.lineColor) === 0
                    ? chroma((_e = config === null || config === void 0 ? void 0 : config.palette) === null || _e === void 0 ? void 0 : _e.lineColor).rgb().join(',')
                    : '255, 255, 255'},${(_f = config === null || config === void 0 ? void 0 : config.palette) === null || _f === void 0 ? void 0 : _f.lineAlpha})`;
                styles.backgroundColor = `rgba(${((_g = config === null || config === void 0 ? void 0 : config.palette) === null || _g === void 0 ? void 0 : _g.fillColor) || ((_h = config === null || config === void 0 ? void 0 : config.palette) === null || _h === void 0 ? void 0 : _h.fillColor) === 0
                    ? chroma((_j = config === null || config === void 0 ? void 0 : config.palette) === null || _j === void 0 ? void 0 : _j.fillColor).rgb().join(',')
                    : '255, 255, 255'},${(_k = config === null || config === void 0 ? void 0 : config.palette) === null || _k === void 0 ? void 0 : _k.fillAlpha})`;
            }
        }
        if (config === null || config === void 0 ? void 0 : config.x) {
            styles.left = config.x;
        }
        if (config === null || config === void 0 ? void 0 : config.y) {
            styles.top = config.y;
        }
        if (config === null || config === void 0 ? void 0 : config.z) {
            styles.zIndex = config.z || 0;
        }
        if (config === null || config === void 0 ? void 0 : config.height) {
            styles.height = config.height;
        }
        // attempts are being constantly updated, if we are not careful it will re-render the activity
        // too many times. instead we want to only send the "initial" attempt state
        // activities should then keep track of updates internally and if needed request updates
        const activities = currentActivityTree.map((activity) => {
            const attempt = currentActivityAttemptTree === null || currentActivityAttemptTree === void 0 ? void 0 : currentActivityAttemptTree.find((a) => (a === null || a === void 0 ? void 0 : a.activityId) === activity.resourceId);
            if (!attempt) {
                console.error('could not find attempt state for ', activity);
                return;
            }
            const activityKey = historyModeNavigation ? `${activity.id}_history` : activity.id;
            return (<ActivityRenderer key={activityKey} activity={activity} attempt={attempt} onActivitySave={handleActivitySave} onActivitySubmit={handleActivitySubmit} onActivitySavePart={handleActivitySavePart} onActivitySubmitPart={handleActivitySubmitPart} onActivityReady={handleActivityReady} onRequestLatestState={handleActivityRequestLatestState}/>);
        });
        return (<div className="content" style={styles}>
        {activities}
      </div>);
    }, [currentActivityTree, lessonStyles]);
    useEffect(() => {
        if (!isEnd) {
            return;
        }
        const tutorialScoreOp = {
            target: 'session.tutorialScore',
            operator: '+',
            value: '{session.currentQuestionScore}',
        };
        const currentScoreOp = {
            target: 'session.currentQuestionScore',
            operator: '=',
            value: 0,
        };
        bulkApplyState([tutorialScoreOp, currentScoreOp], defaultGlobalEnv);
        const tutScore = getValue('session.tutorialScore', defaultGlobalEnv) || 0;
        const curScore = getValue('session.currentQuestionScore', defaultGlobalEnv) || 0;
        dispatch(setScore({ score: tutScore + curScore }));
        // we shouldn't have to send this to the server, it should already be calculated there
    }, [isEnd]);
    return (<div ref={fieldRef} className={activityClasses.join(' ')}>
      <style>{`style { display: none !important; }`}</style>
      <DeckLayoutHeader pageName={pageTitle} userName={currentUserName} activityName="" showScore={true} themeId={(_c = pageContent === null || pageContent === void 0 ? void 0 : pageContent.custom) === null || _c === void 0 ? void 0 : _c.themeId}/>
      <div className={backgroundClasses.join(' ')} style={backgroundStyles}/>
      {pageContent ? (<div className="stageContainer columnRestriction" style={lessonStyles}>
          <InjectedStyles css={pageContent === null || pageContent === void 0 ? void 0 : pageContent.customCss}/>
          <div id="stage-stage">
            <div className="stage-content-wrapper">{renderActivities()}</div>
          </div>
        </div>) : (<div>loading...</div>)}
      <DeckLayoutFooter />
    </div>);
};
export default DeckLayoutView;
//# sourceMappingURL=DeckLayoutView.jsx.map