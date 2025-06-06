import React, { useCallback, useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { ActivityState, StudentResponse } from 'components/activities/types';
import {
  defaultGlobalEnv,
  evalAssignScript,
  getLocalizedStateSnapshot,
} from 'adaptivity/scripting';
import ActivityRenderer from 'apps/delivery/components/ActivityRenderer';
import { getLocalizedCurrentStateSnapshot } from 'apps/delivery/store/features/adaptivity/actions/getLocalizedCurrentStateSnapshot';
import { triggerCheck } from 'apps/delivery/store/features/adaptivity/actions/triggerCheck';
import { selectCurrentActivityTree } from 'apps/delivery/store/features/groups/selectors/deck';
import { toggleEverapp } from 'apps/delivery/store/features/page/actions/toggleEverapp';
import { selectBlobStorageProvider, selectPreviewMode } from 'apps/delivery/store/features/page/slice';
import { updateGlobalUserState } from 'data/persistence/extrinsic';
import { getEverAppActivity, updateAttemptGuid } from '../EverApps';

export interface Everapp {
  id: string;
  name: string;
  url: string;
  iconUrl: string;
  isVisible: boolean;
}

export interface IEverappRendererProps {
  index: number;
  app: Everapp;
  open: boolean;
}

const EverappRenderer: React.FC<IEverappRendererProps> = (props) => {
  const everApp = props.app;
  const index = props.index;

  const dispatch = useDispatch();
  const isPreviewMode = useSelector(selectPreviewMode);
  const [isOpen, setIsOpen] = useState<boolean>(props.open);
  const blobStorageProvider = useSelector(selectBlobStorageProvider);
  const currentActivityTree = useSelector(selectCurrentActivityTree);

  useEffect(() => {
    setIsOpen(props.open);
  }, [props.open]);

  const handleEverappActivityReady = useCallback(async () => {
    if (!currentActivityTree) {
      console.warn('[EverApp] READY BUT NO TREE????', props);
      return; // very bad!
    }
    const currentActivityIds = currentActivityTree.map((a) => String(a.id));
    return {
      snapshot: getLocalizedStateSnapshot(currentActivityIds),
      context: {
        currentActivity: currentActivityTree[currentActivityTree.length - 1].id,
        mode: 'VIEWER', // TODO ENUM
      },
    };
  }, [currentActivityTree]);

  const handleActivitySavePart = async (
    activityId: string | number,
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => {
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
    const responseMap = response.input.reduce((result: any, item: any) => {
      result[item.id] = item.value;
      return result;
    }, {});
    // need to update scripting env
    evalAssignScript(responseMap, defaultGlobalEnv);

    // because the everapp attemptGuid and partAttemptGuid are always made up
    // can't save it like normal, instead setData should cover it
    const result = await updateGlobalUserState(blobStorageProvider, updatedState, isPreviewMode);

    /* console.log('EVERAPP SAVE PART', {
      activityId,
      attemptGuid,
      partAttemptGuid,
      response,
      responseMap,
      updatedState,
      result,
    }); */

    const sResult = await dispatch(getLocalizedCurrentStateSnapshot());
    const {
      payload: { snapshot },
    } = sResult as any;
    return { result, snapshot };
  };

  const handleActivitySubmitPart = async (
    activityId: string | number,
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => {
    const { result, snapshot } = await handleActivitySavePart(
      activityId,
      attemptGuid,
      partAttemptGuid,
      response,
    );

    dispatch(triggerCheck({ activityId: activityId.toString() }));

    return { result, snapshot };
  };

  const handleRequestLatestState = async () => {
    const sResult = await dispatch(getLocalizedCurrentStateSnapshot());
    const {
      payload: { snapshot },
    } = sResult as any;
    return {
      snapshot,
    };
  };

  const handleCloseClick = useCallback(() => {
    setIsOpen(false);
    dispatch(toggleEverapp({ id: everApp.id }));
  }, [everApp]);

  return (
    <div
      className={`beagleAppSidebarView beagleApp-${everApp.id} ${isOpen ? 'open' : 'displayNone'}`}
    >
      <div className="appHeader">
        <div className="appTitle">{everApp.name}</div>
        <div className="closeBtn icon-clear" onClick={handleCloseClick}></div>
      </div>

      <div className="appContainer">
        <ActivityRenderer
          key={everApp.id}
          activity={getEverAppActivity(everApp, everApp.url, index)}
          attempt={updateAttemptGuid(index, everApp) as ActivityState}
          onActivitySave={async () => true}
          onActivitySubmit={async () => true}
          onActivitySavePart={handleActivitySavePart}
          onActivitySubmitPart={handleActivitySubmitPart}
          onActivityReady={handleEverappActivityReady}
          onRequestLatestState={handleRequestLatestState}
          adaptivityDomain="app"
          isEverApp={true}
          blobStorageProvider={blobStorageProvider}
        />
      </div>
    </div>
  );
};

export default EverappRenderer;
