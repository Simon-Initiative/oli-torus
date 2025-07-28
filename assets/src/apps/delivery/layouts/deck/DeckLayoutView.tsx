/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useMemo, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import chroma from 'chroma-js';
import { ActivityState, PartResponse, StudentResponse } from 'components/activities/types';
import { getLocalizedCurrentStateSnapshot } from 'apps/delivery/store/features/adaptivity/actions/getLocalizedCurrentStateSnapshot';
import {
  ApplyStateOperation,
  bulkApplyState,
  defaultGlobalEnv,
  evalScript,
  getLocalizedStateSnapshot,
  getValue,
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
  selectSequence,
} from '../../store/features/groups/selectors/deck';
import {
  selectBlobStorageProvider,
  selectPageSlug,
  selectReviewMode,
  selectSectionSlug,
  selectUserId,
  selectUserName,
  setScore,
} from '../../store/features/page/slice';
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
  const currentLesson = useSelector(selectPageSlug);
  const sectionSlug = useSelector(selectSectionSlug);
  const currentUserId = useSelector(selectUserId);
  const blobStorageProvider = useSelector(selectBlobStorageProvider);
  const currentUserName = useSelector(selectUserName);
  const historyModeNavigation = useSelector(selectHistoryNavigationActivity);
  const reviewMode = useSelector(selectReviewMode);
  const isEnd = useSelector(selectLessonEnd);
  const sequence = useSelector(selectSequence);
  const defaultClasses: any[] = useMemo(
    () => ['lesson-loaded', previewMode ? 'previewView' : 'lessonView'],
    [previewMode],
  );
  const [pageClasses, setPageClasses] = useState<string[]>([]);
  const [activityClasses, setActivityClasses] = useState<string[]>([...defaultClasses]);
  const [lessonStyles, setLessonStyles] = useState<any>({});

  // Background
  const backgroundClasses = ['background'];
  const backgroundStyles: CSSProperties = {};
  if (pageContent?.custom?.backgroundImageURL) {
    backgroundStyles.backgroundImage = `url('${pageContent.custom.backgroundImageURL}')`;
  }
  if (pageContent?.custom?.backgroundImageScaleContent) {
    backgroundClasses.push('background-scaled');
  }
  const getCustomClassAncestry = useCallback(() => {
    let className = '';
    if (currentActivityTree) {
      currentActivityTree.forEach((activity) => {
        if (activity?.content?.custom?.customCssClass) {
          className += ' ' + activity?.content?.custom?.customCssClass;
        }
      });
    }

    return className;
  }, [currentActivityTree]);

  const extractCustomCssClassFactsFromTree = useCallback(async () => {
    const extractedFacts: any[] = [];

    if (!currentActivityTree) return extractedFacts;

    currentActivityTree.forEach((activity) => {
      const customFacts = activity?.content?.custom?.facts?.map((fact: any) => {
        const isCustomCssClass = fact?.target?.includes('customCssClass');
        const isStageScoped = fact?.target?.startsWith('stage.');

        if (!isCustomCssClass) return;

        if (!isStageScoped) {
          return { ...fact, value: fact?.value };
        }

        // this logic is same as we have in deck.ts --> initializeActivity()
        const [, partId] = fact.target.split('.');
        const parentActivity = currentActivityTree.find((a) =>
          a.content?.partsLayout?.some((p: any) => p.id === partId),
        );

        if (!parentActivity) return { ...fact };

        return {
          ...fact,
          target: `${parentActivity.id}|${fact.target}`,
        };
      });

      extractedFacts.push(...(customFacts?.filter(Boolean) || []));
    });

    return extractedFacts;
  }, [currentActivityTree]);

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

    const lessonWidth = pageContent.custom.defaultScreenWidth || '100%';
    const lessonHeight = pageContent.custom.defaultScreenHeight;
    // TODO: add a flag to lesson data use the height?
    const useLessonHeight = false;
    setLessonStyles(() => {
      const styles: any = {
        width: lessonWidth,
      };
      if (useLessonHeight) {
        styles.height = lessonHeight;
      }
      return styles;
    });

    if (pageContent?.customScript) {
      // apply a custom *janus* script if defined
      // this is for user defined functions (also legacy)
      // TODO: something if there are errors
      try {
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        const csResult = evalScript(pageContent?.customScript, defaultGlobalEnv);
        /* console.log('Lesson Custom Script: ', {
        script: pageContent?.customScript,
        csResult,
      }); */
      } catch (e) {
        console.error('Error in custom script: ', e);
      }
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

          const stmt = `let {variables.${v.name.trim()}} = ${expr};`;
          return stmt;
        })
        .filter((s: any) => s);
      // execute each sequentially in case there are errors (missing functions)
      statements.forEach((statement) => {
        try {
          evalScript(statement, defaultGlobalEnv);
        } catch (e) {
          console.error('Error found processing variables: ', e);
        }
      });
    }
  }, [pageContent]);

  useEffect(() => {
    if (!currentActivityTree || currentActivityTree.length === 0) {
      return;
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
      }, 10000);
    });
    sharedActivityPromise = { promise, resolve, reject };

    const currentActivity = currentActivityTree[currentActivityTree.length - 1];

    currentActivityTree.forEach((activity) => {
      // need to leave the layers as already initialized assuming they are already initialized
      // but the current screen should always be false, sometimes we come back to a screen as a new initialization
      if (!sharedActivityInit.has(activity.id) || activity.id === currentActivity.id) {
        /* console.log(
          '[AllActivitiesInit] SETTING INIT FALSE FOR: ',
          activity.id,
          currentActivity.id,
        ); */
        sharedActivityInit.set(activity.id, false);
      }
    });

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
      if (historyModeNavigation || reviewMode) {
        console.log(
          '[AllActivitiesInit] historyModeNavigation or reviewMode is ON, clearing sharedActivityInit',
        );
        sharedActivityInit.clear();
      }
    };
  }, [
    currentActivityTree,
    defaultClasses,
    getCustomClassAncestry,
    historyModeNavigation,
    reviewMode,
    pageClasses,
  ]);

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
    await dispatch(initializeActivity(currentActivity.resourceId!));
  }, [currentActivityTree, dispatch]);

  const handleActivityReady = useCallback(
    async (activityId: string | number, attemptGuid: string) => {
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
        if (!historyModeNavigation || reviewMode) {
          await initCurrentActivity();
        }
        if (historyModeNavigation) {
          // We need to apply the initial state for `customCssClass` because it may contain logic
          // that dynamically applies styles like `display-none` to components.
          // In history mode, the initial state isn't applied to the snapshot by default,
          // so we must manually extract and apply any `customCssClass`-related state.
          const initState = await extractCustomCssClassFactsFromTree();
          if (initState?.length) {
            await bulkApplyState(initState, defaultGlobalEnv);
          }
        }
        const currentActivityIds = (currentActivityTree || []).map((a) => a.id);
        const snapshot = getLocalizedStateSnapshot(currentActivityIds);
        const context = {
          snapshot,
          context: {
            currentLesson,
            sectionSlug,
            currentUserId,
            currentActivity: currentActivityTree[currentActivityTree.length - 1].id,
            mode: historyModeNavigation || reviewMode ? contexts.REVIEW : contexts.VIEWER,
          },
        };

        console.log('DECK HANDLE READY (ALL ACTIVITIES DONE INIT)', { context });

        sharedActivityPromise.resolve(context);
        dispatch(setInitPhaseComplete(true));
      }
      return sharedActivityPromise.promise;
    },
    [
      currentActivityTree,
      currentLesson,
      sectionSlug,
      currentUserId,
      dispatch,
      historyModeNavigation,
      reviewMode,
      initCurrentActivity,
    ],
  );

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

  const getStatePrefix = (path: string, activityId: string | number) => {
    const parts = path.split('.');
    const partId = parts[0];

    const ownerActivity = currentActivityTree?.find(
      (activity) => !!(activity.content?.partsLayout || []).find((p: any) => p.id === partId),
    );
    if (ownerActivity) {
      return `${ownerActivity.id}|stage`;
    } else {
      return `${activityId}|stage`;
    }
  };

  const handleActivitySavePart = useCallback(
    async (
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
      let statePrefix = `${activityId}|stage`;
      if (response.input?.length) {
        // Even if the current screen is a child screen, we always save the part component properties with their owner activity Id i.e. ownerActivityId|stage.iframe.visible = true.
        // The entire response is from one part, so the path (i.e. partId.properyName) will be same for all input response
        // Hence we check the owner activity id once.
        statePrefix = getStatePrefix(response.input[0].path, activityId);
      }
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
      if (historyModeNavigation || reviewMode) {
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
    },
    [currentActivityTree, dispatch, historyModeNavigation, reviewMode],
  );

  const handleActivitySubmitPart = useCallback(
    async (
      activityId: string | number,
      attemptGuid: string,
      partAttemptGuid: string,
      response: StudentResponse,
    ) => {
      if (reviewMode) return;
      // save before submitting
      const { result, snapshot } = await handleActivitySavePart(
        activityId,
        attemptGuid,
        partAttemptGuid,
        response,
      );

      dispatch(triggerCheck({ activityId: activityId.toString() }));

      return { result, snapshot };
    },
    [dispatch, handleActivitySavePart, reviewMode],
  );

  const handleActivityRequestLatestState = useCallback(async () => {
    const sResult = await dispatch(getLocalizedCurrentStateSnapshot());
    const {
      payload: { snapshot },
    } = sResult as any;
    return {
      snapshot,
    };
  }, [dispatch]);

  const [localActivityTree, setLocalActivityTree] = useState<any>(currentActivityTree);
  const [triggerWindowsScrollPosition, setTriggerWindowsScrollPosition] = useState(false);
  const [scrollPosition, setScrollPosition] = useState(0);

  useEffect(() => {
    if (currentActivityTree && currentActivityTree?.length > 1) {
      const currentActivity = currentActivityTree[currentActivityTree.length - 1];
      const previousActivity = currentActivityTree[currentActivityTree.length - 2];

      const currentSequence = sequence?.filter(
        (entry) => entry.custom.sequenceId === currentActivity.id,
      );

      const previousSquence = sequence?.filter(
        (entry) => entry.custom.sequenceId === previousActivity?.id,
      );
      if (triggerWindowsScrollPosition && currentSequence.length && previousSquence.length) {
        //when a user is navigated to next scree, if the new screen is child screen of the existing screen
        // then we need to maintain the scroll position of the user
        const currentScreenOwnerId = currentSequence[0].custom?.layerRef;
        const previousScreenSequenceId = previousSquence[0].custom?.sequenceId;
        if (currentScreenOwnerId === previousScreenSequenceId) {
          window.scrollTo(0, scrollPosition);
          setTriggerWindowsScrollPosition(false);
        }
      }
    }
  }, [currentActivityTree, triggerWindowsScrollPosition, scrollPosition, sequence]);

  const handleScroll = () => {
    const position = window.scrollY;
    setScrollPosition(position);
  };

  useEffect(() => {
    window.addEventListener('scroll', handleScroll, { passive: true });

    return () => {
      window.removeEventListener('scroll', handleScroll);
    };
  }, []);

  useEffect(() => {
    setLocalActivityTree((currentLocalTree: any) => {
      if (!currentActivityTree) {
        return null;
      }

      const currentActivity = currentActivityTree[currentActivityTree.length - 1];

      if (!currentLocalTree) {
        return currentActivityTree
          ? currentActivityTree.map((activity) => ({
              ...activity,
              activityKey:
                historyModeNavigation || reviewMode
                  ? `${activity.id}_${currentActivity.id}_history`
                  : activity.id,
            }))
          : null;
      }

      const currentLocalActivity = currentLocalTree[currentLocalTree.length - 1];
      // if the current and current local are the same, then we don't need to do anything
      if (currentLocalActivity.id === currentActivity.id) {
        setTriggerWindowsScrollPosition(false);
        return currentLocalTree;
      }
      setTriggerWindowsScrollPosition(true);
      return currentActivityTree.map((activity) => ({
        ...activity,
        activityKey: historyModeNavigation
          ? `${activity.id}_${currentActivity.id}_history`
          : activity.id,
      }));
    });
  }, [currentActivityTree, historyModeNavigation, reviewMode]);

  const renderActivities = useCallback(() => {
    if (!localActivityTree || !localActivityTree.length) {
      return <div>loading...</div>;
    }

    const actualCurrentActivity = localActivityTree[localActivityTree.length - 1];
    const config = actualCurrentActivity.content.custom;
    const styles: CSSProperties = {
      width: config?.width || lessonStyles.width,
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
    const activities = localActivityTree.map((activity: any) => {
      const attempt = currentActivityAttemptTree?.find(
        (a) => a?.activityId === activity.resourceId,
      );
      if (!attempt) {
        // this will happen but I think it should be OK because it will call this method again
        // when the attempt tree is updated, and next time it will have the state
        /* console.warn('could not find attempt state for ', activity.id); */
        return;
      } else {
        /* console.log('found attempt state for ', activity.id); */
      }

      return (
        <ActivityRenderer
          key={activity.activityKey}
          activity={activity}
          attempt={attempt as ActivityState}
          onActivitySave={handleActivitySave}
          onActivitySubmit={handleActivitySubmit}
          onActivitySavePart={handleActivitySavePart}
          onActivitySubmitPart={handleActivitySubmitPart}
          onActivityReady={handleActivityReady}
          onRequestLatestState={handleActivityRequestLatestState}
          blobStorageProvider={blobStorageProvider}
        />
      );
    });

    return (
      <div className="content" style={styles}>
        {activities}
      </div>
    );
  }, [
    currentActivityAttemptTree,
    localActivityTree,
    handleActivityReady,
    handleActivityRequestLatestState,
    handleActivitySavePart,
    handleActivitySubmitPart,
    lessonStyles.width,
  ]);

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
  }, [dispatch, isEnd]);

  return (
    <div ref={fieldRef} className={activityClasses.join(' ')}>
      <style>{`style { display: none !important; }`}</style>
      <DeckLayoutHeader
        pageName={pageTitle}
        backUrl={pageContent?.backUrl}
        userName={currentUserName}
        activityName=""
        showScore={true}
        themeId={pageContent?.custom?.themeId}
      />
      <div className={backgroundClasses.join(' ')} style={backgroundStyles} />
      {pageContent ? (
        <div className="stageContainer columnRestriction" style={lessonStyles}>
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
