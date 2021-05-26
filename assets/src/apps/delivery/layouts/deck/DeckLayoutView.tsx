/* eslint-disable react/prop-types */
import chroma from 'chroma-js';
import { ActivityState, PartResponse, StudentResponse } from 'components/activities/types';
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { defaultGlobalEnv, getEnvState } from '../../../../adaptivity/scripting';
import ActivityRenderer from '../../components/ActivityRenderer';
import { triggerCheck } from '../../store/features/adaptivity/actions/triggerCheck';
import { savePartState } from '../../store/features/attempt/actions/savePart';
import { initializeActivity } from '../../store/features/groups/actions/deck';
import {
  selectCurrentActivityTree,
  selectCurrentActivityTreeAttemptState,
} from '../../store/features/groups/selectors/deck';
import { LayoutProps } from '../layouts';
import DeckLayoutFooter from './DeckLayoutFooter';
import DeckLayoutHeader from './DeckLayoutHeader';

// TODO: need to factor this into a "legacy" flagged behavior
const InjectedStyles: React.FC = () => {
  return (
    <style>
      {`.content *  {text-decoration: none; padding: 0px; margin:0px;white-space: normal; font-family: Arial; font-size: 13px; font-style: normal;border: none; border-collapse: collapse; border-spacing: 0px;line-height: 1.4; color: black; font-weight:inherit;color: inherit; display: inline-block; -moz-binding: none; text-decoration: none; white-space: normal; border: 0px; max-width:none;}
        .content sup  {vertical-align: middle; font-size:65%; font-style:inherit;}
        .content sub  {vertical-align: middle; font-size:65%; font-style:inherit;}
        .content em  {font-style:italic; display:inline; font-size:inherit;}
        .content strong  {font-weight:bold; display:inline; font-size:inherit;}
        .content label  {margin-right:2px; display:inline-block; cursor:auto;}
        .content div  {display:inline-block; margin-top:1px}
        .content input  {margin:0px;}
        .content span  {display:inline; font-size:inherit;}
        .content option {display:block;}
        .content ul {display:block}
        .content ol {display:block}`}
    </style>
  );
};

const sharedActivityInit = new Map();
let sharedActivityPromise: any;

const DeckLayoutView: React.FC<LayoutProps> = ({ pageTitle, pageContent, previewMode }) => {
  const dispatch = useDispatch();
  const fieldRef = React.useRef<HTMLInputElement>(null);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const currentActivityAttemptTree = useSelector(selectCurrentActivityTreeAttemptState);

  const defaultClasses: any[] = ['lesson-loaded', previewMode ? 'previewView' : 'lessonView'];
  const [pageClasses, setPageClasses] = useState<string[]>([]);
  const [activityClasses, setActivityClasses] = useState<string[]>([...defaultClasses]);
  const [contentStyles, setContentStyles] = useState<any>({});

  // Background
  const backgroundClasses = ['background'];
  const backgroundStyles: CSSProperties = {};
  if (pageContent?.custom?.backgroundImageURL) {
    backgroundStyles.backgroundImage = `url('${pageContent.custom.backgroundImageURL}')`;
  }
  if (pageContent?.custom?.backgroundImageScaleContent) {
    backgroundClasses.push('background-scaled');
  }

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
    const customClasses = currentActivity.content?.custom?.customCssClass;
    /* if (currentActivity.custom?.layerRef) {
      customClasses = `${customClasses} ${getCustomClassAncestry(
        currentActivity.custom?.layerRef,
      )}`;
    } */
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
    } else if (currentActivity?.content?.partsLayout) {
      // check if activities have vft
      // BS: TODO check whole tree for vft (often is in parent layer)
      const hasVft: boolean = currentActivity?.content?.partsLayout.some(
        (part: any) => part.id === 'vft',
      );

      if (hasVft) {
        // set new class list after check for duplicate strings
        // & strip whitespace from array strings
        setActivityClasses([...new Set([...defaultClasses, 'vft'])].map((str) => str.trim()));
      }
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

  const getLocalizedStateSnapshot = () => {
    const snapshot = getEnvState(defaultGlobalEnv);
    const finalState: any = { ...snapshot };
    const allActivityIds = (currentActivityTree || []).map((a) => a.id);
    allActivityIds.forEach((activityId: string) => {
      const activityState = Object.keys(snapshot)
        .filter((key) => key.indexOf(`${activityId}|`) === 0)
        .reduce((collect: any, key) => {
          const localizedKey = key.replace(`${activityId}|`, '');
          collect[localizedKey] = snapshot[key];
          return collect;
        }, {});
      Object.assign(finalState, activityState);
    });
    return finalState;
  };

  const initCurrentActivity = useCallback(async () => {
    if (!currentActivityTree) {
      return;
    }
    const currentActivity = currentActivityTree[currentActivityTree.length - 1];
    if (!currentActivity) {
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
      sharedActivityPromise.resolve({ snapshot: getLocalizedStateSnapshot() });
    }
    return sharedActivityPromise.promise;
  };

  const handleActivitySave = async (
    activityId: string | number,
    attemptGuid: string,
    partResponses: PartResponse[],
  ) => {
    /* console.log('DECK HANDLE SAVE', { activityId, attemptGuid, partResponses }); */

    return true;
  };

  const handleActivitySubmit = async (
    activityId: string | number,
    attemptGuid: string,
    partResponses: PartResponse[],
  ) => {
    /* console.log('DECK HANDLE SUBMIT', { activityId, attemptGuid, partResponses }); */
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
    const result = await dispatch(
      savePartState({ attemptGuid, partAttemptGuid, response: responseMap }),
    );
    return { result, snapshot: getLocalizedStateSnapshot() };
  };

  const handleActivitySubmitPart = async (
    activityId: string | number,
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => {
    const { result, snapshot } = await handleActivitySavePart(
      activityId,
      attemptGuid,
      partAttemptGuid,
      response,
    );

    dispatch(triggerCheck({ activityId: activityId.toString() }));

    return { result, snapshot };
  };

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
      return (
        <ActivityRenderer
          key={activity.id}
          activity={activity}
          attempt={attempt as ActivityState}
          onActivitySave={handleActivitySave}
          onActivitySubmit={handleActivitySubmit}
          onActivitySavePart={handleActivitySavePart}
          onActivitySubmitPart={handleActivitySubmitPart}
          onActivityReady={handleActivityReady}
        />
      );
    });

    return (
      <div className="content" style={styles}>
        {activities}
      </div>
    );
  }, [currentActivityTree]);

  return (
    <div ref={fieldRef} className={activityClasses.join(' ')}>
      <DeckLayoutHeader
        pageName={pageTitle}
        userName="TODO: (User Name)"
        activityName="TODO: (Activity Name)"
        scoreValue={0}
        showScore={true}
        themeId={pageContent?.custom?.themeId}
      />
      <div className={backgroundClasses.join(' ')} style={backgroundStyles} />
      {pageContent ? (
        <div className="stageContainer columnRestriction" style={contentStyles}>
          <InjectedStyles />
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
