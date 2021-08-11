/* eslint-disable react/prop-types */
import chroma from 'chroma-js';
import { ActivityState, PartResponse, StudentResponse } from 'components/activities/types';
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
  ApplyStateOperation,
  bulkApplyState,
  defaultGlobalEnv,
  evalScript,
  getEnvState,
  getLocalizedStateSnapshot,
  getValue,
  removeStateValues,
} from '../../../../adaptivity/scripting';
import { contexts } from '../../../../types/applicationContext';
import ActivityRenderer from '../../components/ActivityRenderer';
import { triggerCheck } from '../../store/features/adaptivity/actions/triggerCheck';
import {
  selectHistoryNavigationActivity,
  selectLessonEnd,
  setInitPhaseComplete,
} from '../../store/features/adaptivity/slice';
import { savePartState, savePartStateToTree } from '../../store/features/attempt/actions/savePart';
import { initializeActivity } from '../../store/features/groups/actions/deck';
import {
  selectCurrentActivityTree,
  selectCurrentActivityTreeAttemptState,
} from '../../store/features/groups/selectors/deck';
import { selectEnableHistory, selectUserName, setScore } from '../../store/features/page/slice';
import { LayoutProps } from '../layouts';
import DeckLayoutFooter from './DeckLayoutFooter';
import DeckLayoutHeader from './DeckLayoutHeader';

const InjectedStyles: React.FC<{ css?: string }> = (props) => {
  // migrated legacy include as customCss
  // BS: do we need a default?
  const defaultCss = '';
  const injected = props.css || defaultCss;
  return injected ? <style>{injected}</style> : null;
};

const sharedActivityInit = new Map();
let sharedActivityPromise: any;

const DeckLayoutView: React.FC<LayoutProps> = ({ pageTitle, pageContent, previewMode }) => {
  const dispatch = useDispatch();
  const fieldRef = React.useRef<HTMLInputElement>(null);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const currentActivityAttemptTree = useSelector(selectCurrentActivityTreeAttemptState);
  const currentUserName = useSelector(selectUserName);
  const historyModeNavigation = useSelector(selectHistoryNavigationActivity);
  const isEnd = useSelector(selectLessonEnd);
  const defaultClasses: any[] = ['lesson-loaded', previewMode ? 'previewView' : 'lessonView'];
  const [pageClasses, setPageClasses] = useState<string[]>([]);
  const [activityClasses, setActivityClasses] = useState<string[]>([...defaultClasses]);
  const [contentStyles, setContentStyles] = useState<any>({});
  const enableHistory = useSelector(selectEnableHistory);
  // Background
  const backgroundClasses = ['background'];
  const backgroundStyles: CSSProperties = {};
  if (pageContent?.custom?.backgroundImageURL) {
    backgroundStyles.backgroundImage = `url('${pageContent.custom.backgroundImageURL}')`;
  }
  if (pageContent?.custom?.backgroundImageScaleContent) {
    backgroundClasses.push('background-scaled');
  }
  const getCustomClassAncestry = () => {
    let className = '';
    if (currentActivityTree) {
      currentActivityTree.forEach((activity) => {
        if (activity?.content?.custom?.customCssClass) {
          className += activity?.content?.custom?.customCssClass;
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
    if (!pageContent) {
      return;
    }

    // set page class on change
    if (pageContent?.custom?.viewerSkin) {
      setPageClasses([`skin-${pageContent.custom.viewerSkin}`]);
    }

    const contentStyle: any = {
      // doesn't appear that SS is adding height
      // height: currentPage.custom?.defaultScreenHeight,
      width: pageContent.custom?.defaultScreenWidth,
    };
    setContentStyles(contentStyle);

    if (pageContent?.custom?.customScript) {
      // apply a custom *janus* script if defined
      // this is for user defined functions (also legacy)
      // TODO: something if there are errors
      evalScript(pageContent?.custom?.customScript, defaultGlobalEnv);
    }

    if (Array.isArray(pageContent?.custom?.variables)) {
      const allNames = pageContent.custom.variables.map((v: any) => v.name);
      // variables can and will ref previous ones
      // they will reference them "globally" so need to track the above
      // in order to prepend the "variables" namespace
      const statements: string[] = pageContent.custom.variables
        .map((v: any) => {
          if (!v.name || !v.expression) {
            return '';
          }
          let expr = v.expression;
          allNames.forEach((name: string) => {
            const regex = new RegExp(`{${name}}`, 'g');
            expr = expr.replace(regex, `{variables.${name}}`);
          });

          const stmt = `let {variables.${v.name}} = ${expr};`;
          return stmt;
        })
        .filter((s: any) => s);
      // execute each sequentially in case there are errors (missing functions)
      statements.forEach((statement) => {
        evalScript(statement, defaultGlobalEnv);
      });
    }
  }, [pageContent]);

  useEffect(() => {
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

      const idsToBeRemoved: any[] = Object.keys(globalSnapshot).filter(
        (key: string) =>
          key.indexOf('stage.') === 0 || key.indexOf(`${currentActivity.id}|stage.`) === 0,
      ); /*
      console.log('REMOVING STATE VALUES: ', idsToBeRemoved); */
      if (idsToBeRemoved.length) {
        removeStateValues(defaultGlobalEnv, idsToBeRemoved);
      }
    }
    let timeout: NodeJS.Timeout;
    let resolve;
    let reject;
    const promise = new Promise((res, rej) => {
      let resolved = false;
      resolve = (value: any) => {
        resolved = true;
        res(value);
      };
      reject = (reason: string) => {
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
      }, 4000);
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
    let customClasses = currentActivity.content?.custom?.customCssClass || '';

    if (currentActivityTree.length) {
      customClasses = `${customClasses} ${getCustomClassAncestry()}`;
    }
    setActivityClasses([...defaultClasses, customClasses]);
    if (fieldRef.current) {
      fieldRef.current.scrollIntoView();
    }

    if (currentActivity?.custom?.customCssClass) {
      // split space delimited strings into array of strings
      const customClasses = currentActivity.content?.customCssClass?.split(' ') || [];
      customClasses.map((c: string) => {
        if (c === 'defaultFeedback') {
          setPageClasses([...new Set([...pageClasses, c])]);
        }
      });

      // set new class list after check for duplicate strings
      // & strip whitespace from array strings
      setActivityClasses(
        [...new Set([...defaultClasses, ...customClasses])].map((str) => str.trim()),
      );
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

  const initCurrentActivity = useCallback(async () => {
    if (!currentActivityTree) {
      console.error('[initCurrentActivity] no currentActivityTree');
      return;
    }
    const currentActivity = currentActivityTree[currentActivityTree.length - 1];
    if (!currentActivity) {
      console.error('[initCurrentActivity] bad tree??', currentActivityTree);
      return;
    }
    await dispatch(initializeActivity(currentActivity.resourceId));
  }, [currentActivityTree]);

  const handleActivityReady = async (activityId: string | number, attemptGuid: string) => {
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
    if (currentActivityTree?.every((activity) => sharedActivityInit.get(activity.id) === true)) {
      await initCurrentActivity();
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
  };

  const handleActivitySave = async (
    activityId: string | number,
    attemptGuid: string,
    partResponses: PartResponse[],
  ) => {
    /* console.log('DECK HANDLE SAVE', { activityId, attemptGuid, partResponses }); */
    // TODO: currently not used.
    return true;
  };

  const handleActivitySubmit = async (
    activityId: string | number,
    attemptGuid: string,
    partResponses: PartResponse[],
  ) => {
    /* console.log('DECK HANDLE SUBMIT', { activityId, attemptGuid, partResponses }); */
    // TODO: currently not used.
    return true;
  };

  const handleActivitySavePart = async (
    activityId: string | number,
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => {
    /* console.log('DECK HANDLE SAVE PART', {
      activityId,
      attemptGuid,
      partAttemptGuid,
      response,
      currentActivityTree,
    }); */
    const statePrefix = `${activityId}|stage`;
    const responseMap = response.input.reduce(
      (result: { [x: string]: any }, item: { key: string; path: string }) => {
        result[item.key] = { ...item, path: `${statePrefix}.${item.path}` };
        return result;
      },
      {},
    );

    const currentActivityIds = (currentActivityTree || []).map((a) => a.id);
    if (!currentActivityTree || !currentActivityTree.length) {
      // throw instead?
      return { result: 'error' };
    }

    //if user navigated from history, don't save anything and just return the saved state
    if (historyModeNavigation) {
      return { result: null, snapshot: getLocalizedStateSnapshot(currentActivityIds) };
    }

    if (response?.input?.length) {
      let result;
      // in addition to the current part attempt, need to lookup in the tree
      // if this part is an inherited part and also write to the child attempt records
      const currentActivity = currentActivityTree[currentActivityTree.length - 1];
      if (currentActivity.id !== activityId) {
        // this means that the part is inherted (we are a layer or parent screen)
        // so we need to update all children in the tree with this part response as well
        result = await dispatch(
          savePartStateToTree({
            attemptGuid,
            partAttemptGuid,
            response: responseMap,
            activityTree: currentActivityTree,
          }),
        );
      } else {
        result = await dispatch(
          savePartState({ attemptGuid, partAttemptGuid, response: responseMap }),
        );
      }
      return { result, snapshot: getLocalizedStateSnapshot(currentActivityIds) };
    } else {
      return { result: null, snapshot: getLocalizedStateSnapshot(currentActivityIds) };
    }
  };

  const handleActivitySubmitPart = async (
    activityId: string | number,
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => {
    // save before submitting
    const { result, snapshot } = await handleActivitySavePart(
      activityId,
      attemptGuid,
      partAttemptGuid,
      response,
    );

    dispatch(triggerCheck({ activityId: activityId.toString() }));

    return { result, snapshot };
  };

  const handleActivityRequestLatestState = useCallback(async () => {
    const currentActivityIds = (currentActivityTree || []).map((a) => a.id);
    return { snapshot: getLocalizedStateSnapshot(currentActivityIds) };
  }, [currentActivityTree]);

  const renderActivities = useCallback(() => {
    if (!currentActivityTree || !currentActivityTree.length) {
      return <div>loading...</div>;
    }

    const actualCurrentActivity = currentActivityTree[currentActivityTree.length - 1];
    const config = actualCurrentActivity.content.custom;
    const styles: CSSProperties = {
      width: config?.width || 1300,
    };
    if (config?.palette) {
      if (config.palette.useHtmlProps) {
        styles.backgroundColor = config.palette.backgroundColor;
        styles.borderColor = config.palette.borderColor;
        styles.borderWidth = config.palette.borderWidth;
        styles.borderStyle = config.palette.borderStyle;
        styles.borderRadius = config.palette.borderRadius;
      } else {
        styles.borderWidth = `${
          config?.palette?.lineThickness ? config?.palette?.lineThickness + 'px' : '1px'
        }`;
        styles.borderRadius = '10px';
        styles.borderStyle = 'solid';
        styles.borderColor = `rgba(${
          config?.palette?.lineColor || config?.palette?.lineColor === 0
            ? chroma(config?.palette?.lineColor).rgb().join(',')
            : '255, 255, 255'
        },${config?.palette?.lineAlpha})`;
        styles.backgroundColor = `rgba(${
          config?.palette?.fillColor || config?.palette?.fillColor === 0
            ? chroma(config?.palette?.fillColor).rgb().join(',')
            : '255, 255, 255'
        },${config?.palette?.fillAlpha})`;
      }
    }
    if (config?.x) {
      styles.left = config.x;
    }
    if (config?.y) {
      styles.top = config.y;
    }
    if (config?.z) {
      styles.zIndex = config.z || 0;
    }
    if (config?.height) {
      styles.height = config.height;
    }

    // attempts are being constantly updated, if we are not careful it will re-render the activity
    // too many times. instead we want to only send the "initial" attempt state
    // activities should then keep track of updates internally and if needed request updates
    const activities = currentActivityTree.map((activity) => {
      const attempt = currentActivityAttemptTree?.find(
        (a) => a?.activityId === activity.resourceId,
      );
      if (!attempt) {
        console.error('could not find attempt state for ', activity);
        return;
      }
      const activityKey = historyModeNavigation ? `${activity.id}_history` : activity.id;

      return (
        <ActivityRenderer
          key={activityKey}
          activity={activity}
          attempt={attempt as ActivityState}
          onActivitySave={handleActivitySave}
          onActivitySubmit={handleActivitySubmit}
          onActivitySavePart={handleActivitySavePart}
          onActivitySubmitPart={handleActivitySubmitPart}
          onActivityReady={handleActivityReady}
          onRequestLatestState={handleActivityRequestLatestState}
        />
      );
    });

    return (
      <div className="content" style={styles}>
        {activities}
      </div>
    );
  }, [currentActivityTree]);

  useEffect(() => {
    if (!isEnd) {
      return;
    }

    const tutorialScoreOp: ApplyStateOperation = {
      target: 'session.tutorialScore',
      operator: '+',
      value: '{session.currentQuestionScore}',
    };
    const currentScoreOp: ApplyStateOperation = {
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

  return (
    <div ref={fieldRef} className={activityClasses.join(' ')}>
      <DeckLayoutHeader
        pageName={pageTitle}
        userName={currentUserName}
        activityName=""
        showScore={true}
        themeId={pageContent?.custom?.themeId}
      />
      <div className={backgroundClasses.join(' ')} style={backgroundStyles} />
      {pageContent ? (
        <div className="stageContainer columnRestriction" style={contentStyles}>
          <InjectedStyles css={pageContent?.customCss} />
          <div id="stage-stage">
            <div className="stage-content-wrapper">{renderActivities()}</div>
          </div>
        </div>
      ) : (
        <div>loading...</div>
      )}
      <DeckLayoutFooter />
    </div>
  );
};

export default DeckLayoutView;
