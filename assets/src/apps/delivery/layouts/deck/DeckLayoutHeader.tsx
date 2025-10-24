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

const MaximizeIcon = () => (
  <svg
    width="24"
    height="19"
    viewBox="0 0 24 19"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    role="img"
    aria-hidden="true"
  >
    <title>Maximize</title>
    <path
      d="M6.375 15.8814C6.98438 15.8814 7.5 16.397 7.5 17.0064C7.5 17.6627 6.98438 18.1314 6.375 18.1314H1.125C0.46875 18.1314 0 17.6627 0 17.0064V11.7564C0 11.147 0.46875 10.6314 1.125 10.6314C1.73438 10.6314 2.25 11.147 2.25 11.7564V15.8814H6.375ZM6.375 0.131409C6.98438 0.131409 7.5 0.647034 7.5 1.25641C7.5 1.91266 6.98438 2.38141 6.375 2.38141H2.25V6.50641C2.25 7.16266 1.73438 7.63141 1.125 7.63141C0.46875 7.63141 0 7.16266 0 6.50641V1.25641C0 0.647034 0.46875 0.131409 1.125 0.131409H6.375ZM22.875 0.131409C23.4844 0.131409 24 0.647034 24 1.25641V6.50641C24 7.16266 23.4844 7.63141 22.875 7.63141C22.2188 7.63141 21.75 7.16266 21.75 6.50641V2.38141H17.625C16.9688 2.38141 16.5 1.91266 16.5 1.25641C16.5 0.647034 16.9688 0.131409 17.625 0.131409H22.875ZM22.875 10.6314C23.4844 10.6314 24 11.147 24 11.7564V17.0064C24 17.6627 23.4844 18.1314 22.875 18.1314H17.625C16.9688 18.1314 16.5 17.6627 16.5 17.0064C16.5 16.397 16.9688 15.8814 17.625 15.8814H21.75V11.7564C21.75 11.147 22.2188 10.6314 22.875 10.6314Z"
      fill="white"
    />
  </svg>
);

const MinimizeIcon = () => (
  <svg
    width="24"
    height="18"
    viewBox="0 0 24 18"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    role="img"
    aria-hidden="true"
  >
    <title>Minimize</title>
    <path
      d="M17.625 7.5C16.9688 7.5 16.5 7.03125 16.5 6.375V1.125C16.5 0.515625 16.9688 0 17.625 0C18.2344 0 18.75 0.515625 18.75 1.125V5.25H22.875C23.4844 5.25 24 5.76562 24 6.375C24 7.03125 23.4844 7.5 22.875 7.5H17.625ZM6.375 10.5C6.98438 10.5 7.5 11.0156 7.5 11.625V16.875C7.5 17.5312 6.98438 18 6.375 18C5.71875 18 5.25 17.5312 5.25 16.875V12.75H1.125C0.46875 12.75 0 12.2812 0 11.625C0 11.0156 0.46875 10.5 1.125 10.5H6.375ZM22.875 10.5C23.4844 10.5 24 11.0156 24 11.625C24 12.2812 23.4844 12.75 22.875 12.75H18.75V16.875C18.75 17.5312 18.2344 18 17.625 18C16.9688 18 16.5 17.5312 16.5 16.875V11.625C16.5 11.0156 16.9688 10.5 17.625 10.5H22.875ZM6.375 0C6.98438 0 7.5 0.515625 7.5 1.125V6.375C7.5 7.03125 6.98438 7.5 6.375 7.5H1.125C0.46875 7.5 0 7.03125 0 6.375C0 5.76562 0.46875 5.25 1.125 5.25H5.25V1.125C5.25 0.515625 5.71875 0 6.375 0Z"
      fill="white"
    />
  </svg>
);

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
  const [isFullscreen, setIsFullscreen] = useState(false);

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

  const toggleFullscreen = () => {
    const iframe = window.parent.document.getElementById('adaptive_content_iframe');
    const container = window.parent.document.getElementById('adaptive_with_chrome_container');

    if (!iframe || !container) return;

    setIsFullscreen(!isFullscreen);

    if (!isFullscreen) {
      // Enter fullscreen mode - apply CSS class to iframe
      iframe.classList.add('fullscreen-iframe');
      container.classList.add('fullscreen-container');
    } else {
      // Exit fullscreen mode - remove CSS class
      iframe.classList.remove('fullscreen-iframe');
      container.classList.remove('fullscreen-container');
    }
  };

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
            border-radius: 0 0 4px 4px;
            background-color: rgba(0, 0, 0, 0.2);
            transition: background-color .15s ease-in-out;
          }
          .back-button:hover {
            background-color: rgba(0, 0, 0, 0.35);
          }
          .back-button a {
            text-decoration: none;
            padding: 4px 10px;
            font-size: 1.3rem;
            line-height: 1.5;
            color: #6c757d;
            border: 1px solid #6c757d;
            border-top: none;
            border-radius: 0 0 4px 4px;
            background: transparent;
            cursor: pointer;
            transition: color .15s ease-in-out, background-color .15s ease-in-out, box-shadow .15s ease-in-out;
          }
          .back-button a:hover {
            color: #fff;
            background-color: #6c757d;
            box-shadow: 0 1px 2px #00000079;
          }
          .back-button button {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 100%;
            height: 100%;
            padding: 16px;
            color: #6c757d;
            border: none;
            background: transparent;
            cursor: pointer;
          }
          .back-button button svg {
            display: block;
          }
          `}
          </style>
          {currentPage.displayApplicationChrome ? (
            <button
              onClick={toggleFullscreen}
              title={isFullscreen ? 'Minimize' : 'Maximize'}
              aria-label={isFullscreen ? 'Minimize' : 'Maximize'}
              aria-pressed={isFullscreen}
            >
              {isFullscreen ? <MinimizeIcon /> : <MaximizeIcon />}
            </button>
          ) : (
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
