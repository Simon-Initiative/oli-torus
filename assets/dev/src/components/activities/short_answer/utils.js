import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { getCorrectResponse, getIncorrectResponse, getResponsesByPartId, Responses, } from 'data/activities/model/responses';
import { makeHint, makeStem, ScoringStrategy } from '../types';
export const defaultModel = () => {
    return {
        stem: makeStem(''),
        inputType: 'text',
        authoring: {
            parts: [
                {
                    id: DEFAULT_PART_ID,
                    scoringStrategy: ScoringStrategy.average,
                    responses: Responses.forTextInput(),
                    hints: [makeHint(''), makeHint(''), makeHint('')],
                },
            ],
            transformations: [],
            previewText: '',
        },
    };
};
export const getTargetedResponses = (model, partId) => getResponsesByPartId(model, partId).filter((response) => response !== getCorrectResponse(model, partId) &&
    response !== getIncorrectResponse(model, partId));
export const shortAnswerOptions = [
    { value: 'numeric', displayValue: 'Number' },
    { value: 'text', displayValue: 'Short Text' },
    { value: 'textarea', displayValue: 'Paragraph' },
];
//# sourceMappingURL=utils.js.map