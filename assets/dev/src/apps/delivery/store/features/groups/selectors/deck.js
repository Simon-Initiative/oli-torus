import { createSelector } from '@reduxjs/toolkit';
import { selectAllActivities, selectCurrentActivityId } from '../../activities/slice';
import { selectActivityAttemptState } from '../../attempt/slice';
import { getSequenceLineage } from '../actions/sequence';
import { selectState } from '../slice';
export const selectSequence = createSelector(selectState, (state) => {
    if (state.currentGroupId === -1) {
        return [];
    }
    const currentGroup = state.entities[state.currentGroupId];
    return currentGroup ? currentGroup.children : [];
});
export const selectCurrentSequenceId = createSelector([selectSequence, selectCurrentActivityId], (sequence, currentActivityId) => {
    var _a;
    /* console.log('SELECT CURRENT SEQUENCE ID', { sequence, currentActivityId }); */
    return (_a = sequence.find((entry) => {
        // temp hack for authoring
        // TODO: rewire delivery to use resourceId instead of sequenceId
        let testId = entry.custom.sequenceId;
        if (typeof currentActivityId === 'number') {
            testId = entry.resourceId;
        }
        return testId === currentActivityId;
    })) === null || _a === void 0 ? void 0 : _a.custom.sequenceId;
});
export const selectCurrentActivityTree = createSelector([selectSequence, selectAllActivities, selectCurrentSequenceId], (sequence, activities, currentSequenceId) => {
    const currentSequenceEntry = sequence.find((entry) => entry.custom.sequenceId === currentSequenceId);
    if (!currentSequenceEntry) {
        // because this is a selector, might be undefined; stringify to display that
        // TODO: Logging System that can be turned off in prod and/or instrumented
        console.warn(`Current Activity ${JSON.stringify(currentSequenceId)} not found in sequence!`);
        return null;
    }
    const lineage = getSequenceLineage(sequence, currentSequenceEntry.custom.sequenceId);
    const tree = lineage.map((entry) => activities.find((a) => a.resourceId === entry.resourceId));
    /*  console.log('TREE', { lineage, activities }); */
    // filtering out undefined, however TODO make sure they are loaded ahead of time!
    return tree.filter((t) => t);
});
export const selectCurrentActivityTreeAttemptState = createSelector((state) => {
    const currentTree = selectCurrentActivityTree(state);
    const attempts = currentTree === null || currentTree === void 0 ? void 0 : currentTree.map((t) => selectActivityAttemptState(state, t.resourceId));
    return [currentTree, attempts];
}, ([currentTree, attempts]) => {
    if (!(currentTree === null || currentTree === void 0 ? void 0 : currentTree.length) || !(attempts === null || attempts === void 0 ? void 0 : attempts.length)) {
        return;
    }
    const mappedTree = currentTree.map((activity) => {
        const attempt = attempts.find((a) => a.activityId === activity.resourceId);
        return attempt;
    });
    return mappedTree;
});
//# sourceMappingURL=deck.js.map