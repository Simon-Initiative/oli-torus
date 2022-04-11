import React, { useEffect, useState } from 'react';
import { useSelector } from 'react-redux';
import {
  selectPageContent,
  selectPageSlug,
  selectPreviewMode,
  selectScore,
  selectSectionSlug,
} from '../../store/features/page/slice';
import EverappMenu from './components/EverappMenu';
import { Everapp } from './components/EverappRenderer';
import OptionsPanel from './components/OptionsPanel';

interface DeckLayoutHeaderProps {
  pageName?: string;
  activityName?: string;
  showScore?: boolean;
  themeId?: string;
  userName?: string;
}

const DeckLayoutHeader: React.FC<DeckLayoutHeaderProps> = ({
  pageName,
  activityName,
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

  const [backButtonUrl, setBackButtonUrl] = useState('');
  const [backButtonText, setBackButtonText] = useState('Back to Overview');

  const projectSlug = useSelector(selectSectionSlug);
  const resourceSlug = useSelector(selectPageSlug);

  useEffect(() => {
    if (isPreviewMode) {
      // return to authoring
      setBackButtonUrl(`/authoring/project/${projectSlug}/resource/${resourceSlug}`);
      setBackButtonText('Back to Authoring');
    } else {
      setBackButtonUrl(window.location.href.split('/page')[0] + '/overview');
      setBackButtonText('Back to Overview');
    }
  }, [isPreviewMode]);

  return (
    <div className="headerContainer">
      <div className="back-button">
        <style>
          {`
          .back-button {
            display: flex;
            width: 100px;
          }
          .back-button a {
              display: flex;
              height: 3em;
              width: 100px;
              align-items: center;
              justify-content: center;
              background-color: #eee;
              border-radius: 3px;
              cursor: pointer;
              border: 1px solid;
              position: absolute;
              top: 4px;
              left: 4px;
              text-decoration: none;
          }
          `}
        </style>
        <a href={backButtonUrl} title={backButtonText}>
          Back
        </a>
      </div>
      <header id="delivery-header">
        <div className="defaultView">
          <h1 className="lessonTitle">{pageName}</h1>
          <h2 className="questionTitle">{activityName}</h2>
          <div className={`wrapper ${!isLegacyTheme ? 'displayNone' : ''}`}>
            <div className="nameScoreButtonWrapper">
              {/* <a className="trapStateListToggle">Force Adaptivity</a> */}
              {isLegacyTheme && hasEverApps && <EverappMenu apps={everApps} />}

              <div className="name">{userName}</div>
              <div className={`score ${!showScore ? 'displayNone' : ''}`}>{scoreText}</div>
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
            </div>
            <OptionsPanel open={showOptions} />
          </div>
          <div className={`theme-header ${isLegacyTheme ? 'displayNone' : ''}`}>
            <div className={`theme-header-score ${!showScore ? 'displayNone' : ''}`}>
              <div className="theme-header-score__icon"></div>
              <span className="theme-header-score__label">Score:&nbsp;</span>
              <span className="theme-header-score__value">{scoreText}</span>
            </div>
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
              {!isLegacyTheme && hasEverApps && <EverappMenu apps={everApps} />}
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
