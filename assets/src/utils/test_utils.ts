import produce from 'immer';

export const dispatch = <Model>(model: Model, action: any): Model => {
  return produce(model, (draftState) => action(draftState, () => undefined));
};
