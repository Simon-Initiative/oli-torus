import produce from 'immer';
export const dispatch = (model, action) => {
    return produce(model, (draftState) => action(draftState, () => undefined));
};
//# sourceMappingURL=test_utils.js.map