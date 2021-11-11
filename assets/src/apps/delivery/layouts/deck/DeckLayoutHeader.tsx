/* eslint-disable react/prop-types */
import React from 'react';
import { useSelector } from 'react-redux';
import { selectPageContent, selectScore } from '../../store/features/page/slice';
import EverappMenu from './components/EverappMenu';
import { Everapp } from './components/EverappRenderer';
import EverAppContainer from './EverAppContainer';

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

  return (
    <div className="headerContainer">
      <header id="delivery-header">
        <div className="defaultView">
          <h1 className="lessonTitle">{pageName}</h1>
          <h2 className="questionTitle">{activityName}</h2>
          <div className={`wrapper ${!isLegacyTheme ? 'displayNone' : ''}`}>
            <div className="nameScoreButtonWrapper">
              {/* <a className="trapStateListToggle">Force Adaptivity</a> */}
              {/* beagleToggleContainer here */}
              {isLegacyTheme && hasEverApps && <EverappMenu apps={everApps} />}

              <div className="name">{userName}</div>
              <div className={`score ${!showScore ? 'displayNone' : ''}`}>{scoreText}</div>
              {/* optionsToggle here */}
            </div>
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
