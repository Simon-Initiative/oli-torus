import ActivityRenderer from 'apps/delivery/components/ActivityRenderer';
import { selectCurrentActivityTree } from 'apps/delivery/store/features/groups/selectors/deck';
import { ActivityState } from 'components/activities/types';
import React, { useState } from 'react';
import { OverlayTrigger, Popover } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import {
  defaultGlobalEnv,
  evalScript,
  getLocalizedStateSnapshot,
} from '../../../../adaptivity/scripting';
import { selectPageContent } from '../../store/features/page/slice';
import { getEverAppActivity, udpateAttemptGuid } from './EverApps';

const EverAppContainer = () => {
  const [isPopoverOpen, setIsPopoverOpen] = useState<boolean>(false);
  const currentPage = useSelector(selectPageContent);
  const everApps = currentPage?.custom?.everApps;

  const currentActivityTree = useSelector(selectCurrentActivityTree);

  const handleEverappActivityReady = React.useCallback(async () => {
    if (!currentActivityTree) {
      return; // very bad!
    }
    const currentActivityIds = currentActivityTree.map((a) => a.id);
    return {
      snapshot: getLocalizedStateSnapshot(currentActivityIds),
      context: {
        currentActivity: currentActivityTree[currentActivityTree.length - 1].id,
        mode: 'VIEWER', // TODO ENUM
      },
    };
  }, [currentActivityTree]);

  return (
    <div className={'beagle'} style={{ order: 3 }}>
      {everApps && everApps.length && (
        <OverlayTrigger
          trigger="click"
          placement={'bottom'}
          container={document.getElementById('delivery-header')}
          onExit={() => setIsPopoverOpen(false)}
          overlay={
            <Popover id="parent-popover" style={{ zIndex: 9999, opacity: 1, marginTop: '10px' }}>
              <div className="arrow" style={{ display: 'none' }}></div>
              <Popover.Content>
                <div className="customDiv">
                  {everApps?.map(
                    (everApp: any, index: number) =>
                      everApp.isVisible && (
                        <OverlayTrigger
                          key={everApp.id}
                          trigger="click"
                          placement="bottom"
                          rootClose={true}
                          container={document.getElementById('delivery-header')}
                          onExit={() => {
                            setIsPopoverOpen(false);
                            evalScript(`let app.active = "none";`, defaultGlobalEnv);
                          }}
                          onEntered={() => {
                            evalScript(`let app.active = "${everApp.id}";`, defaultGlobalEnv);
                          }}
                          overlay={
                            <div style={{ zIndex: 9999, opacity: 1, marginTop: '5px' }}>
                              <ActivityRenderer
                                key={everApp.id}
                                activity={getEverAppActivity(everApp, everApp.url, index)}
                                attempt={udpateAttemptGuid(index, everApp) as ActivityState}
                                onActivitySave={() => {}}
                                onActivitySubmit={() => {}}
                                onActivitySavePart={() => {}}
                                onActivitySubmitPart={() => {}}
                                onActivityReady={handleEverappActivityReady}
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
                                onError={(ev) => {
                                  const element = ev.target as HTMLImageElement;
                                  element.src = '/images/icons/icon-nine-dots.svg';
                                }}
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
            <img src={'/images/icons/icon-nine-dots.svg'}></img>
          </button>
        </OverlayTrigger>
      )}
    </div>
  );
};

export default EverAppContainer;
