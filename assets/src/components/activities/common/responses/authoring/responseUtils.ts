import { getByIdUnsafe } from 'components/activities/common/authoring/utils';
import { HasParts } from 'components/activities/types';
import { ID } from 'data/content/model';

// Responses
export const getResponses = (model: HasParts) => model.authoring.parts[0].responses;
export const getResponse = (model: HasParts, id: string) => getByIdUnsafe(getResponses(model), id);

// Rules
export const createRuleForIds = (toMatch: ID[], notToMatch: ID[]) =>
  unionRules(
    toMatch.map(createMatchRule).concat(notToMatch.map((id) => invertRule(createMatchRule(id)))),
  );
export const createMatchRule = (id: string) => `input like {${id}}`;
export const invertRule = (rule: string) => `(!(${rule}))`;
export const unionTwoRules = (rule1: string, rule2: string) => `${rule2} && (${rule1})`;
export const unionRules = (rules: string[]) => rules.reduce(unionTwoRules);
