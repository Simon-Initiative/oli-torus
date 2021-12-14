// returns the next random QB child
export const getNextQBEntry = (sequence, bank, viewHistory) => {
    var _a;
    // determines how many QB child screens to randomly show
    const bankShowCount = ((_a = bank.custom) === null || _a === void 0 ? void 0 : _a.bankShowCount) || 0;
    const bankChildren = getBankChildren(sequence, bank);
    const viewedChildren = getViewedChildren(bankChildren, viewHistory);
    if (viewedChildren.length >= bankShowCount) {
        return getQBEndTarget(sequence, bank);
    }
    const remainingChildren = getRemainingChildren(bankChildren, viewedChildren);
    // generates a random index based on remainingChildren.length
    const random = Math.floor(Math.random() * remainingChildren.length);
    // return the next random QB child screen
    return remainingChildren[random];
};
// finds the parent QB of the current screen
export const getParentBank = (sequence, currentIndex) => {
    const bank = sequence.find((s) => s.custom.sequenceId === sequence[currentIndex].custom.layerRef && s.custom.isBank === true);
    return bank || null;
};
// generates a list of all the QB child screens
export const getBankChildren = (sequence, parentBank) => sequence.filter((s) => s.custom.layerRef === parentBank.custom.sequenceId);
// generates a list of QB child screens that have already been viewed
export const getViewedChildren = (bankChildren, viewHistory) => {
    const viewedHistoryIds = viewHistory.filter((v) => v.visitCount >= 1).map((v) => v.sequenceId);
    const viewedChildren = bankChildren
        .filter((bc) => viewedHistoryIds.includes(bc.custom.sequenceId))
        .map((v) => v.custom.sequenceId);
    return viewedChildren;
};
// determines which QB children are remaining to be viewed
export const getRemainingChildren = (bankChildren, viewedChildrenIds) => bankChildren.filter((bc) => !viewedChildrenIds.includes(bc.custom.sequenceId));
// returns the bankEndTarget of the QB
export const getQBEndTarget = (sequence, parentBank) => {
    const bankEndTarget = parentBank.custom.bankEndTarget;
    const bankChildren = getBankChildren(sequence, parentBank);
    //** if bankEndTarget = next or undefined then we need to find the correct next ensemble to navigate to */
    //** if bankEndTarget is something like q:1573069617189:646 then do nothing */
    if ((bankChildren && bankEndTarget === 'next') || !bankEndTarget) {
        const lastQBChild = bankChildren[bankChildren.length - 1].custom.sequenceId;
        const currentIndex = sequence.findIndex((s) => s.custom.sequenceId === lastQBChild);
        const nextIndex = currentIndex + 1;
        return sequence[nextIndex];
    }
    return sequence.find((s) => s.custom.sequenceId === bankEndTarget) || null;
};
//# sourceMappingURL=navUtils.js.map