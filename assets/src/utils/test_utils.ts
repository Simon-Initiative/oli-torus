import produce from 'immer';

export const applyTestAction = <Model>(model: Model, action: any) => {
  return produce(model, action);
};
