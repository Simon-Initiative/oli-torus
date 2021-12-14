import { setDifference } from 'components/activities/common/utils';
import { Maybe } from 'tsmonad';
export const invertRule = (rule) => `(!(${rule}))`;
const andTwoRules = (rule1, rule2) => `${rule2} && (${rule1})`;
export const andRules = (...rules) => rules.reduce(andTwoRules);
const orTwoRules = (rule1, rule2) => `${rule2} || (${rule1})`;
export const orRules = (...rules) => rules.reduce(orTwoRules);
export const isCatchAllResponse = (response) => response.rule === '.*';
export function isOperator(s) {
    return [
        'contains',
        'notcontains',
        'regex',
        'gt',
        'gte',
        'eq',
        'lt',
        'lte',
        'neq',
        'btw',
        'nbtw',
    ].includes(s);
}
// text
export const matchRule = (input) => `input like {${input}}`;
export const containsRule = (input) => `input contains {${input}}`;
export const notContainsRule = (input) => invertRule(containsRule(input));
// numeric
export const eqRule = (input) => `input = {${input}}`;
export const neqRule = (input) => invertRule(eqRule(input));
export const ltRule = (input) => `input < {${input}}`;
export const lteRule = (input) => orRules(ltRule(input), eqRule(input));
export const gtRule = (input) => `input > {${input}}`;
export const gteRule = (input) => orRules(gtRule(input), eqRule(input));
const makeBtwRule = (lesser, greater) => andRules(orRules(gtRule(lesser), eqRule(lesser)), orRules(ltRule(greater), eqRule(greater)));
export const btwRule = (left, right) => {
    const parsedLeft = parseFloat(left);
    const parsedRight = parseFloat(right);
    if (Number.isNaN(parsedLeft) || Number.isNaN(parsedRight)) {
        return makeBtwRule('0', '0');
    }
    const lesser = parsedLeft < parsedRight ? left : right;
    const greater = lesser === left ? right : left;
    return makeBtwRule(lesser, greater);
};
export const nbtwRule = (left, right) => invertRule(btwRule(left, right));
export const makeRule = (operator, input) => {
    if (typeof input === 'string') {
        switch (operator) {
            case 'gt':
                return gtRule(input);
            case 'gte':
                return gteRule(input);
            case 'lt':
                return ltRule(input);
            case 'lte':
                return lteRule(input);
            case 'eq':
                return eqRule(input);
            case 'neq':
                return neqRule(input);
            case 'contains':
                return containsRule(input);
            case 'notcontains':
                return notContainsRule(input);
            case 'regex':
                return matchRule(input);
        }
    }
    switch (operator) {
        case 'btw':
            return btwRule(input[0], input[1]);
        case 'nbtw':
            return nbtwRule(input[0], input[1]);
    }
    throw new Error('Could not make numeric rule for operator ' + operator + ' and input ' + input);
};
// Look for two equality matches, something like `input = {123} || input = {234}`
const matchBetweenRule = (rule) => rule.match(/= {(\d+)}.* = {(\d+)}/);
export const parseInputFromRule = (rule) => Maybe.maybe(matchBetweenRule(rule)).caseOf({
    just: (betweenMatch) => [betweenMatch[1], betweenMatch[2]],
    nothing: () => parseSingleInput(rule),
});
export const parseSingleInput = (rule) => rule.substring(rule.indexOf('{') + 1, rule.indexOf('}'));
export const parseOperatorFromRule = (rule) => {
    switch (true) {
        // text
        case rule.includes('!') && rule.includes('contains'):
            return 'notcontains';
        case rule.includes('contains'):
            return 'contains';
        case rule.includes('like'):
            return 'regex';
        // numeric
        case ['!', '>', '<', '='].every((op) => rule.includes(op)):
            return 'nbtw';
        case ['>', '<', '='].every((op) => rule.includes(op)):
            return 'btw';
        case rule.includes('>') && rule.includes('='):
            return 'gte';
        case rule.includes('>'):
            return 'gt';
        case rule.includes('<') && rule.includes('='):
            return 'lte';
        case rule.includes('<'):
            return 'lt';
        case rule.includes('!') && rule.includes('='):
            return 'neq';
        case rule.includes('='):
            return 'eq';
        default:
            throw new Error('Operator could not be found in rule ' + rule);
    }
};
export const isTextRule = (rule) => !!rule.match(/contains/) || !!rule.match(/like/);
// Explicitly match all ids in `toMatch` and do not match any ids in `allChoiceIds` \ `toMatch`
export const matchListRule = (all, toMatch) => {
    const notToMatch = setDifference(all, toMatch);
    return andRules(...toMatch.map(matchRule).concat(notToMatch.map((id) => invertRule(matchRule(id)))));
};
// Match the `ordered` list in exactly that order
export const matchInOrderRule = (ordered) => `input like {${ordered.join(' ')}}`;
//# sourceMappingURL=rules.js.map