import ActivityRenderer from 'apps/delivery/components/ActivityRenderer';
import { triggerCheck } from 'apps/delivery/store/features/adaptivity/actions/triggerCheck';
import { savePartState } from 'apps/delivery/store/features/attempt/actions/savePart';
import { selectCurrentActivityTree } from 'apps/delivery/store/features/groups/selectors/deck';
import { ActivityState, StudentResponse } from 'components/activities/types';
import React, { useState } from 'react';
import { OverlayTrigger, Popover } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import {
  defaultGlobalEnv,
  evalScript,
  getLocalizedStateSnapshot,
} from '../../../../adaptivity/scripting';
import { selectPageContent, selectPreviewMode } from '../../store/features/page/slice';
import { getEverAppActivity, udpateAttemptGuid } from './EverApps';
import * as Extrinsic from 'data/persistence/extrinsic';

const EverAppContainer = () => {
  const dispatch = useDispatch();
  const [isPopoverOpen, setIsPopoverOpen] = useState<boolean>(false);
  const currentPage = useSelector(selectPageContent);
  const everApps = currentPage?.custom?.everApps;
  const isPreviewMode = useSelector(selectPreviewMode);

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

  const handleActivitySavePart = React.useCallback(
    async (
      activityId: string | number,
      attemptGuid: string,
      partAttemptGuid: string,
      response: StudentResponse,
    ) => {
      console.log('EVERAPP SAVE PART', {
        activityId,
        attemptGuid,
        partAttemptGuid,
        response,
        currentActivityTree,
      });
      if (!currentActivityTree) {
        return { result: 'error' };
      }
      const responseMap = response.input.reduce(
        (result: { [x: string]: any }, item: { key: string; path: string }) => {
          result[item.key] = { ...item, path: `app.${item.path}` };
          return result;
        },
        {},
      );
      /*
      id: "app.ispk-bio-observer.external.env"
      key: "external.env"
      path: "ispk-bio-observer.external.env"
      type: 2
      value: "{\"Location:\": \"Sonoran Desert\", \"Temperature:\": \"10°C to 48°C\"}"
      */
      const updatedState = response.input.reduce((result: any, item: any) => {
        const [simId] = item.path.split('.');
        result[simId] = result[simId] || {};
        result[simId][item.key] = item.value;
        return result;
      }, {});
      // do I need to update the scripting env??
      const currentActivityIds = currentActivityTree.map((a) => a.id);
      // because the everapp attemptGuid and partAttemptGuid are always made up
      // can't save it like normal, instead setData should cover it
      const result = Extrinsic.updateGlobalUserState(updatedState, isPreviewMode);
      return { result, snapshot: getLocalizedStateSnapshot(currentActivityIds) };
    },
    [currentActivityTree],
  );

  const handleActivitySubmitPart = React.useCallback(
    async (
      activityId: string | number,
      attemptGuid: string,
      partAttemptGuid: string,
      response: StudentResponse,
    ) => {
      // TODO: save anything first? or just triggering check OK??
      if (!currentActivityTree) {
        return; // very bad!
      }
      const currentActivityIds = currentActivityTree.map((a) => a.id);

      dispatch(triggerCheck({ activityId: activityId.toString() }));

      return { result: true, snapshot: getLocalizedStateSnapshot(currentActivityIds) };
    },
    [currentActivityTree],
  );

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
                                onActivitySave={async () => true}
                                onActivitySubmit={async () => true}
                                onActivitySavePart={handleActivitySavePart}
                                onActivitySubmitPart={handleActivitySubmitPart}
                                onActivityReady={handleEverappActivityReady}
                                onRequestLatestState={() => {}}
                                adaptivityDomain="app"
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
