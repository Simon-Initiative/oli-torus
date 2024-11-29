import React, { useEffect, useState } from 'react';
import { useSelector } from 'react-redux';
import {
  selectIsInstructor,
  selectPageContent,
  selectPageSlug,
  selectPreviewMode,
  selectReviewMode,
  selectScore,
  selectSectionSlug,
} from '../../store/features/page/slice';
import EverappMenu from './components/EverappMenu';
import { Everapp } from './components/EverappRenderer';
import OptionsPanel from './components/OptionsPanel';
import ReviewModeNavigation from './components/ReviewModeNavigation';

interface DeckLayoutHeaderProps {
  pageName?: string;
  backUrl?: string;
  activityName?: string;
  showScore?: boolean;
  themeId?: string;
  userName?: string;
}

const DeckLayoutHeader: React.FC<DeckLayoutHeaderProps> = ({
  pageName,
  activityName,
  backUrl,
  showScore = false,
  themeId,
  userName,
}) => {
  const scoreValue = useSelector(selectScore);
  const isLegacyTheme = !themeId;
  const scoreToShow = scoreValue.toFixed(2);
  const scoreText = isLegacyTheme ? `(Score: ${scoreToShow})` : scoreToShow;

  const currentPage = useSelector(selectPageContent);

  const everApps: Everapp[] = currentPage?.custom?.everApps || [];
  const hasEverApps = everApps.filter((a) => a.isVisible).length > 0;

  const [showOptions, setShowOptions] = React.useState(false);

  const isPreviewMode = useSelector(selectPreviewMode);
  const isInstructor = useSelector(selectIsInstructor);
  const isReviewMode = useSelector(selectReviewMode);
  const [backButtonUrl, setBackButtonUrl] = useState(backUrl);
  const [backButtonText, setBackButtonText] = useState('Back to Overview');

  const projectSlug = useSelector(selectSectionSlug);
  const resourceSlug = useSelector(selectPageSlug);

  useEffect(() => {
    if (isPreviewMode && !isInstructor) {
      // return to authoring
      setBackButtonUrl(`/authoring/project/${projectSlug}/resource/${resourceSlug}`);
      setBackButtonText('Back to Authoring');
    } else {
      // if no backUrl is provided, then set it to the section root url
      if (!backUrl) {
        setBackButtonUrl(window.location.href.split('/adaptive_lesson')[0]);
      }

      setBackButtonText('Go back to previous screen');
    }
  }, [isPreviewMode]);

  return (
    <div className="headerContainer">
      {
        <div className="back-button">
          <style>
            {`
          .back-button {
            z-index: 1;
            display: flex;
            align-items: center;
            position: fixed;
            top: 0;
            left:  ${isReviewMode ? 'calc(45% - .65rem)' : 'calc(50% - .65rem)'};
          }
          .back-button a {
            text-decoration: none;
            padding: 4px 10px;
            font-size: 1.3rem;
            line-height: 1.5;
            border-radius: 0 0 4px 4px;
            color: #6c757d;
            border: 1px solid #6c757d;
            border-top: none;
            transition: color .15s ease-in-out, background-color .15s ease-in-out, box-shadow .15s ease-in-out;
          }
          .back-button a:hover {
            color: #fff;
            background-color: #6c757d;
            box-shadow: 0 1px 2px #00000079;
          }
          `}
          </style>
          {currentPage.displayApplicationChrome || (
            <a href={backButtonUrl} title={backButtonText}>
              <span className={` ${isReviewMode ? 'fa fa-reply' : 'fa fa-arrow-left'}`}>
                &nbsp;
              </span>
            </a>
          )}
        </div>
      }
      {isReviewMode && <ReviewModeNavigation></ReviewModeNavigation>}
      <header id="delivery-header">
        <div className="defaultView">
          <h1 className="lessonTitle">{pageName}</h1>
          <h2 className="questionTitle">{activityName}</h2>
          <div className={`wrapper ${!isLegacyTheme ? 'displayNone' : ''}`}>
            <div className="nameScoreButtonWrapper">
              {/* <a className="trapStateListToggle">Force Adaptivity</a> */}
              {isLegacyTheme && hasEverApps && (
                <EverappMenu apps={everApps} isLegacyTheme={isLegacyTheme} />
              )}

              <div className="name">{userName}</div>
              <div className={`score ${!showScore ? 'displayNone' : ''}`}>{scoreText}</div>
              {!isReviewMode && (
                <button
                  className="optionsToggle"
                  title="Toggle menu visibility"
                  aria-label="Toggle menu visibility"
                  onClick={() => {
                    setShowOptions(!showOptions);
                  }}
                >
                  <div className="icon-reorder"></div>
                </button>
              )}
            </div>
            <OptionsPanel open={showOptions} />
          </div>
          <div className={`theme-header ${isLegacyTheme ? 'displayNone' : ''}`}>
            <div className={`theme-header-score ${!showScore ? 'displayNone' : ''}`}>
              <div className="theme-header-score__icon"></div>
              <span className="theme-header-score__label">Score:&nbsp;</span>
              <span className="theme-header-score__value">{scoreText}</span>
            </div>
            {!isLegacyTheme && hasEverApps && (
              <EverappMenu apps={everApps} isLegacyTheme={isLegacyTheme} />
            )}
            <div className="theme-header-profile" style={{ display: 'flex' }}>
              <button
                className="theme-header-profile__toggle"
                title="Toggle Profile Options"
                aria-label="Toggle Profile Options"
                disabled
              >
                <span className="nameScoreButtonWrapper">
                  <div className="theme-header-profile__icon"></div>
                  <span className="theme-header-profile__label">{userName}</span>
                </span>
              </button>
              {/*update panel - logout and update details button*/}
            </div>
            {/*  */}
          </div>
        </div>
      </header>
    </div>
  );
};

export default DeckLayoutHeader;
