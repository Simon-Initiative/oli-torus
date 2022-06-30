export const VariableActions = {
  onUpdateTransformations(transformations: any) {
    return (model: any) => {
      model.authoring.transformations = transformations;
    };
  },
};
