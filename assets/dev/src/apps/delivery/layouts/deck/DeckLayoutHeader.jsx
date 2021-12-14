import React from 'react';
import { useSelector } from 'react-redux';
import { selectPageContent, selectScore } from '../../store/features/page/slice';
import EverappMenu from './components/EverappMenu';
import OptionsPanel from './components/OptionsPanel';
const DeckLayoutHeader = ({ pageName, activityName, showScore = false, themeId, userName, }) => {
    var _a;
    const scoreValue = useSelector(selectScore);
    const isLegacyTheme = !themeId;
    const scoreToShow = scoreValue.toFixed(2);
    const scoreText = isLegacyTheme ? `(Score: ${scoreToShow})` : scoreToShow;
    const currentPage = useSelector(selectPageContent);
    const everApps = ((_a = currentPage === null || currentPage === void 0 ? void 0 : currentPage.custom) === null || _a === void 0 ? void 0 : _a.everApps) || [];
    const hasEverApps = everApps.filter((a) => a.isVisible).length > 0;
    const [showOptions, setShowOptions] = React.useState(false);
    return (<div className="headerContainer">
      <header id="delivery-header">
        <div className="defaultView">
          <h1 className="lessonTitle">{pageName}</h1>
          <h2 className="questionTitle">{activityName}</h2>
          <div className={`wrapper ${!isLegacyTheme ? 'displayNone' : ''}`}>
            <div className="nameScoreButtonWrapper">
              {/* <a className="trapStateListToggle">Force Adaptivity</a> */}
              {isLegacyTheme && hasEverApps && <EverappMenu apps={everApps}/>}

              <div className="name">{userName}</div>
              <div className={`score ${!showScore ? 'displayNone' : ''}`}>{scoreText}</div>
              <button className="optionsToggle" title="Toggle menu visibility" aria-label="Toggle menu visibility" onClick={() => {
            setShowOptions(!showOptions);
        }}>
                <div className="icon-reorder"></div>
              </button>
            </div>
            <OptionsPanel open={showOptions}/>
          </div>
          <div className={`theme-header ${isLegacyTheme ? 'displayNone' : ''}`}>
            <div className={`theme-header-score ${!showScore ? 'displayNone' : ''}`}>
              <div className="theme-header-score__icon"></div>
              <span className="theme-header-score__label">Score:&nbsp;</span>
              <span className="theme-header-score__value">{scoreText}</span>
            </div>
            <div className="theme-header-profile" style={{ display: 'flex' }}>
              <button className="theme-header-profile__toggle" title="Toggle Profile Options" aria-label="Toggle Profile Options" disabled>
                <span className="nameScoreButtonWrapper">
                  <div className="theme-header-profile__icon"></div>
                  <span className="theme-header-profile__label">{userName}</span>
                </span>
              </button>
              {!isLegacyTheme && hasEverApps && <EverappMenu apps={everApps}/>}
              {/*update panel - logout and update details button*/}
            </div>
            {/*  */}
          </div>
        </div>
      </header>
    </div>);
};
export default DeckLayoutHeader;
//# sourceMappingURL=DeckLayoutHeader.jsx.map