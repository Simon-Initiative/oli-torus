var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { defaultGlobalEnv, evalAssignScript, getLocalizedStateSnapshot, } from 'adaptivity/scripting';
import ActivityRenderer from 'apps/delivery/components/ActivityRenderer';
import { getLocalizedCurrentStateSnapshot } from 'apps/delivery/store/features/adaptivity/actions/getLocalizedCurrentStateSnapshot';
import { triggerCheck } from 'apps/delivery/store/features/adaptivity/actions/triggerCheck';
import { selectCurrentActivityTree } from 'apps/delivery/store/features/groups/selectors/deck';
import { toggleEverapp } from 'apps/delivery/store/features/page/actions/toggleEverapp';
import { selectPreviewMode } from 'apps/delivery/store/features/page/slice';
import { updateGlobalUserState } from 'data/persistence/extrinsic';
import React, { useCallback, useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { getEverAppActivity, udpateAttemptGuid } from '../EverApps';
const EverappRenderer = (props) => {
    const everApp = props.app;
    const index = props.index;
    const dispatch = useDispatch();
    const isPreviewMode = useSelector(selectPreviewMode);
    const [isOpen, setIsOpen] = useState(props.open);
    const currentActivityTree = useSelector(selectCurrentActivityTree);
    useEffect(() => {
        setIsOpen(props.open);
    }, [props.open]);
    const handleEverappActivityReady = useCallback(() => __awaiter(void 0, void 0, void 0, function* () {
        if (!currentActivityTree) {
            console.warn('READY BUT NO TREE????');
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
    }), [currentActivityTree]);
    const handleActivitySavePart = (activityId, attemptGuid, partAttemptGuid, response) => __awaiter(void 0, void 0, void 0, function* () {
        /*
          id: "app.ispk-bio-observer.external.env"
          key: "external.env"
          path: "ispk-bio-observer.external.env"
          type: 2
          value: "{\"Location:\": \"Sonoran Desert\", \"Temperature:\": \"10°C to 48°C\"}"
          */
        const updatedState = response.input.reduce((result, item) => {
            const [simId] = item.path.split('.');
            result[simId] = result[simId] || {};
            result[simId][item.key] = item.value;
            return result;
        }, {});
        const responseMap = response.input.reduce((result, item) => {
            result[item.id] = item.value;
            return result;
        }, {});
        // need to update scripting env
        evalAssignScript(responseMap, defaultGlobalEnv);
        // because the everapp attemptGuid and partAttemptGuid are always made up
        // can't save it like normal, instead setData should cover it
        const result = yield updateGlobalUserState(updatedState, isPreviewMode);
        console.log('EVERAPP SAVE PART', {
            activityId,
            attemptGuid,
            partAttemptGuid,
            response,
            responseMap,
            updatedState,
            result,
        });
        const sResult = yield dispatch(getLocalizedCurrentStateSnapshot());
        const { payload: { snapshot }, } = sResult;
        return { result, snapshot };
    });
    const handleActivitySubmitPart = (activityId, attemptGuid, partAttemptGuid, response) => __awaiter(void 0, void 0, void 0, function* () {
        const { result, snapshot } = yield handleActivitySavePart(activityId, attemptGuid, partAttemptGuid, response);
        dispatch(triggerCheck({ activityId: activityId.toString() }));
        return { result, snapshot };
    });
    const handleRequestLatestState = () => __awaiter(void 0, void 0, void 0, function* () {
        const sResult = yield dispatch(getLocalizedCurrentStateSnapshot());
        const { payload: { snapshot }, } = sResult;
        return {
            snapshot,
        };
    });
    const handleCloseClick = useCallback(() => {
        setIsOpen(false);
        dispatch(toggleEverapp({ id: everApp.id }));
    }, [everApp]);
    return (<div className={`beagleAppSidebarView beagleApp-${everApp.id} ${isOpen ? 'open' : 'displayNone'}`}>
      <div className="appHeader">
        <div className="appTitle">{everApp.name}</div>
        <div className="closeBtn icon-clear" onClick={handleCloseClick}></div>
      </div>

      <div className="appContainer">
        {isOpen && (<ActivityRenderer key={everApp.id} activity={getEverAppActivity(everApp, everApp.url, index)} attempt={udpateAttemptGuid(index, everApp)} onActivitySave={() => __awaiter(void 0, void 0, void 0, function* () { return true; })} onActivitySubmit={() => __awaiter(void 0, void 0, void 0, function* () { return true; })} onActivitySavePart={handleActivitySavePart} onActivitySubmitPart={handleActivitySubmitPart} onActivityReady={handleEverappActivityReady} onRequestLatestState={handleRequestLatestState} adaptivityDomain="app"/>)}
      </div>
    </div>);
};
export default EverappRenderer;
//# sourceMappingURL=EverappRenderer.jsx.map