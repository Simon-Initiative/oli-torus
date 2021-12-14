import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { getCorrectResponse, getResponses, Responses } from 'data/activities/model/responses';
import { matchRule } from 'data/activities/model/rules';
export const mcV1toV2 = (model) => {
    const newModel = {
        stem: model.stem,
        choices: model.choices,
        authoring: {
            version: 2,
            parts: model.authoring.parts,
            transformations: model.authoring.transformations,
            previewText: model.authoring.previewText,
            targeted: [],
        },
    };
    if (!getResponses(newModel).find((r) => r.rule === matchRule('.*'))) {
        newModel.authoring.parts[0].responses = [
            getCorrectResponse(newModel, DEFAULT_PART_ID),
            Responses.catchAll(),
        ];
    }
    return newModel;
};
//# sourceMappingURL=v2.js.map