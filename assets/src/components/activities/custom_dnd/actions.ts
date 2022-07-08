import { CustomDnDSchema } from './schema';
import { createNewPart } from './utils';

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
  editPart(old: string, newId: string) {
    return (model: CustomDnDSchema) => {
      model.authoring.parts.forEach((p) => {
        if (p.id === old) {
          p.id = newId;
        }
      });
    };
  },
  addPart() {
    return (model: CustomDnDSchema) => {
      const randomName = 'part_' + (Math.random() + '').substring(2);
      model.authoring.parts.push(createNewPart(randomName, 'answer1'));
    };
  },
  removePart(id: string) {
    return (model: CustomDnDSchema) => {
      model.authoring.parts = model.authoring.parts.filter((p) => p.id !== id);
    };
  },
};
