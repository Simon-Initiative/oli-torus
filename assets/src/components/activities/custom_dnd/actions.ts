import { CustomDnDSchema } from './schema';

export const CustomDnDActions = {
  editLayoutStyles(layoutStyles: string) {
    return (model: CustomDnDSchema) => {
      model.layoutStyles = layoutStyles;
    };
  },
  editInitiators(initiators: string) {
    return (model: CustomDnDSchema) => {
      model.initiators = initiators;
    };
  },
  editTargetArea(targetArea: string) {
    return (model: CustomDnDSchema) => {
      model.targetArea = targetArea;
    };
  },
};
