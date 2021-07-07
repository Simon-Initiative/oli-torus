import { getByIdUnsafe } from 'components/activities/common/authoring/utils';
import { HasChoices } from 'components/activities/types';

export const getChoices = (model: HasChoices) => model.choices;
export const getChoice = (model: HasChoices, id: string) => getByIdUnsafe(model.choices, id);
