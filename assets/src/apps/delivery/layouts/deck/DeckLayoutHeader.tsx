/* eslint-disable react/prop-types */
import React from 'react';
import { useSelector } from 'react-redux';
import { selectScore } from '../../store/features/page/slice';

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

  return (
    <div className="headerContainer">
      <header>
        <div className="defaultView">
          <h1 className="lessonTitle">{pageName}</h1>
          <h2 className="questionTitle">{activityName}</h2>
          <div className={`wrapper ${!isLegacyTheme ? 'displayNone' : ''}`}>
            <div className="nameScoreButtonWrapper">
              {/* <a className="trapStateListToggle">Force Adaptivity</a> */}
              {/* beagleToggleContainer here */}
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
            {/*beaglecontainer*/}
            <div className="theme-header-profile">
              <button
                className="theme-header-profile__toggle"
                title="Toggle Profile Options"
                aria-label="Toggle Profile Options"
                disabled
              >
                <span>
                  <div className="theme-header-profile__icon"></div>
                  <span className="theme-header-profile__label">{userName}</span>
                </span>
              </button>
              {/*update panel - logout and update details button*/}
            </div>
          </div>
        </div>
      </header>
    </div>
  );
};

export default DeckLayoutHeader;
