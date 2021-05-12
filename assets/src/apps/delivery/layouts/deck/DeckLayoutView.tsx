/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import ActivityRenderer from '../../formats/adaptive/ActivityRenderer';
import { selectCurrentActivity } from '../../store/features/activities/slice';
import { initializeActivity } from '../../store/features/groups/actions/deck';
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

const DeckLayoutView: React.FC<LayoutProps> = ({ pageContent, previewMode }) => {
  const dispatch = useDispatch();
  const fieldRef = React.useRef<HTMLInputElement>(null);
  const currentActivity = useSelector(selectCurrentActivity);

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
    if (!currentActivity) {
      return;
    }

    // dispatch to update state
    dispatch(initializeActivity(currentActivity.resourceId));

    // set loaded and userRole class when currentActivity is loaded
    const customClasses = currentActivity.custom?.customCssClass;
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
      const hasVft: boolean = currentActivity?.content?.partsLayout.some(
        (part: any) => part.id === 'vft',
      );

      if (hasVft) {
        // set new class list after check for duplicate strings
        // & strip whitespace from array strings
        setActivityClasses([...new Set([...defaultClasses, 'vft'])].map((str) => str.trim()));
      }
    }
  }, [currentActivity]);

  useEffect(() => {
    // clear the body classes in prep for the real classes
    document.body.className = '';

    // strip whitespace and update body class list with page classes
    document.body.classList.add(...pageClasses);
  }, [pageClasses]);

  return (
    <div ref={fieldRef} className={activityClasses.join(' ')}>
      <DeckLayoutHeader
        pageName="TODO: (Page Name)"
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
            <div className="stage-content-wrapper">
              {currentActivity ? (
                <ActivityRenderer
                  config={currentActivity?.content?.custom}
                  parts={currentActivity?.content?.partsLayout}
                />
              ) : (
                <div>loading...</div>
              )}
            </div>
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
