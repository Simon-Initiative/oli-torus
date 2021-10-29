/* eslint-disable react/prop-types */
import React, { useState } from 'react';
import { useSelector } from 'react-redux';
import { selectScore } from '../../store/features/page/slice';
import { OverlayTrigger, Popover } from 'react-bootstrap';
import { EverAppActivity, getEverAppActivity, udpateAttemptGuid } from './EverApps';
import { selectPageContent } from '../../store/features/page/slice';
import { ActivityState } from 'components/activities/types';
import ActivityRenderer from 'apps/delivery/components/ActivityRenderer';
import BeagleLogo from '../../../../../static/images/icons/icon-nine-dots.svg';
import { defaultGlobalEnv, evalScript } from '../../../../adaptivity/scripting';

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

  const [isPopoverOpen, setIsPopoverOpen] = useState<boolean>(false);
  const currentPage = useSelector(selectPageContent);
  const everApps = currentPage?.custom?.everApps;

  // const activityState: ActivityState = {
  //   attemptGuid: 'preview_2946819616',
  //   attemptNumber: 1,
  //   dateEvaluated: null,
  //   score: null,
  //   outOf: null,
  //   parts: [
  //     {
  //       attemptGuid: 'sampleIframeGuid',
  //       attemptNumber: 1,
  //       dateEvaluated: null,
  //       score: null,
  //       outOf: null,
  //       response: null,
  //       feedback: null,
  //       hints: [],
  //       partId: 'janus_capi_iframe-3311152192',
  //       hasMoreAttempts: false,
  //       hasMoreHints: false,
  //     },
  //   ],
  //   hasMoreAttempts: true,
  //   hasMoreHints: true,
  // };

  // const updateEverAppIFrameURL = (everAppObj: any, url: string, index: number) => {
  //   const updatedObject = clone(everAppObj);
  //   updatedObject.id = everAppObj.id + index;
  //   updatedObject.attemptGuid = everAppObj.attemptGuid + index;
  //   updatedObject.content.partsLayout[0].custom.src = url;
  //   return updatedObject;
  // };

  // const udpateAttemptGuid = (index: number) => {
  //   const updatedObject = clone(everAppActivityState);
  //   updatedObject.attemptGuid = everAppActivityState.attemptGuid + index;
  //   return updatedObject;
  // };

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
              <div className="name">{userName}</div>
              <div className={`score ${!showScore ? 'displayNone' : ''}`}>{scoreText}</div>

              <div className={'beagle'} style={{ order: 3 }}>
                <OverlayTrigger
                  trigger="click"
                  placement={'bottom'}
                  container={document.getElementById('delivery-header')}
                  onExit={() => setIsPopoverOpen(false)}
                  overlay={
                    <Popover
                      id="parent-popover"
                      style={{ zIndex: 9999, opacity: 1, marginTop: '10px' }}
                    >
                      <Popover.Content>
                        <div>
                          {everApps?.map(
                            (everApp: any, index: number) =>
                              everApp.isVisible && (
                                <OverlayTrigger
                                  key={everApp.id}
                                  trigger="click"
                                  placement="bottom"
                                  container={document.getElementById('delivery-header')}
                                  onExit={() => {
                                    setIsPopoverOpen(false);
                                    evalScript(`let app.active = "none";`, defaultGlobalEnv);
                                  }}
                                  onEntered={() => {
                                    evalScript(
                                      `let app.active = "${everApp.id}";`,
                                      defaultGlobalEnv,
                                    );
                                  }}
                                  overlay={
                                    <div style={{ zIndex: 9999, opacity: 1, marginTop: '5px' }}>
                                      <ActivityRenderer
                                        key={everApp.id}
                                        activity={getEverAppActivity(
                                          EverAppActivity,
                                          everApp.url,
                                          index,
                                        )}
                                        attempt={udpateAttemptGuid(index) as ActivityState}
                                        onActivitySave={() => {}}
                                        onActivitySubmit={() => {}}
                                        onActivitySavePart={() => {}}
                                        onActivitySubmitPart={() => {}}
                                        onActivityReady={async () => {
                                          return { snapshot: {}, context: { currentActivity: [] } };
                                        }}
                                        onRequestLatestState={() => {}}
                                      />
                                    </div>
                                  }
                                >
                                  <button
                                    style={{
                                      backgroundColor: 'transparent',
                                      backgroundRepeat: 'no-repeat',
                                      border: 'none',
                                      cursor: 'pointer',
                                      overflow: 'hidden',
                                      outline: 'none',
                                    }}
                                  >
                                    <div
                                      style={{
                                        display: 'flex',
                                        flexDirection: 'column',
                                        alignItems: 'center',
                                      }}
                                    >
                                      <img
                                        onError={(ev) => (ev.target.src = BeagleLogo)}
                                        src={everApp.iconUrl}
                                        style={{ height: '30px', width: '30px' }}
                                      ></img>
                                      {everApp.name}
                                    </div>
                                  </button>
                                </OverlayTrigger>
                              ),
                          )}
                        </div>
                      </Popover.Content>
                    </Popover>
                  }
                >
                  <button
                    style={{
                      backgroundColor: 'white',
                      backgroundRepeat: 'no-repeat',
                      border: 'none',
                      cursor: 'pointer',
                      overflow: 'hidden',
                      outline: 'none',
                      marginLeft: '10px',
                      height: '100%',
                    }}
                  >
                    <img src={BeagleLogo}></img>
                  </button>
                </OverlayTrigger>
              </div>

              {/* optionsToggle here */}
            </div>
          </div>
          <div className={`theme-header ${isLegacyTheme ? 'displayNone' : ''}`}>
            <div className={`theme-header-score ${!showScore ? 'displayNone' : ''}`}>
              <div className="theme-header-score__icon"></div>
              <span className="theme-header-score__label">Score:&nbsp;</span>
              <span className="theme-header-score__value">{scoreText}</span>
            </div>
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
