import { clone } from '../../../../utils/common';
import guid from '../../../../utils/guid';
import { IActivity } from '../../../delivery/store/features/activities/slice';
import { Template } from './template-types';

interface HasIdAndChildren {
  id: string;
  children?: HasIdAndChildren[];
}

// The template has id's for all the parts & elements in it, but we need to make sure they're unique, so replace
// them with new ones.
export const replaceIds =
  (idMap: Record<string, string>) =>
  <T extends HasIdAndChildren>(originalPart: T): T => {
    const part = clone(originalPart);

    if (part.children) {
      part.children = part.children.map(replaceIds(idMap));
    }

    if (idMap[part.id]) {
      part.id = idMap[part.id];
      return part;
    }

    const newId = guid();
    idMap[part.id] = newId;
    part.id = newId;
    return part;
  };

export const applyTemplateToActivity = (
  activity: IActivity,
  template: Template,
): IActivity | null => {
  const act = clone(activity) as IActivity;
  if (!act?.content) return null;

  // We need to rewrite the ID's of the parts to be unique, this keeps track of what we change them from/to
  const idMap: Record<string, string> = {};

  if (!act.authoring?.flowchart) {
    console.warn("Screen doesn't have a flowchart object, not applying template");
    return act;
  }

  const newParts = template.parts.map(replaceIds(idMap));
  const newPartsLayout = template.partsLayout.map(replaceIds(idMap));

  act.authoring.parts = newParts;
  act.content.partsLayout = newPartsLayout;
  act.authoring.flowchart.templateApplied = true;

  return act;
};
