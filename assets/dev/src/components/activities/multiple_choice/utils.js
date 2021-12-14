import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { makeChoice, makeHint, makePart, makeStem, makeTransformation, Transform, } from 'components/activities/types';
import { Choices } from 'data/activities/model/choices';
import { getCorrectResponse, Responses } from 'data/activities/model/responses';
import { Maybe } from 'tsmonad';
export const defaultMCModel = () => {
    const choiceA = makeChoice('Choice A');
    const choiceB = makeChoice('Choice B');
    return {
        stem: makeStem(''),
        choices: [choiceA, choiceB],
        authoring: {
            version: 2,
            parts: [
                makePart(Responses.forMultipleChoice(choiceA.id), [makeHint(''), makeHint(''), makeHint('')], DEFAULT_PART_ID),
            ],
            targeted: [],
            transformations: [makeTransformation('choices', Transform.shuffle)],
            previewText: '',
        },
    };
};
export const getCorrectChoice = (model, partId = DEFAULT_PART_ID) => {
    const responseIdMatch = Maybe.maybe(getCorrectResponse(model, partId).rule.match(/{(.*)}/)).valueOrThrow(new Error('Could not find choice id in correct response'));
    return Choices.getOne(model, responseIdMatch[1]);
};
//# sourceMappingURL=utils.js.map