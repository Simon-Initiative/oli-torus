import { PREVIEW_TEXT_PATH, STEM_PATH } from 'data/activities/model/utils';
import { Operations } from 'utils/pathOperations';
import { toSimpleText } from 'components/editing/utils';
export const StemActions = {
    editStem(content, stemPath = STEM_PATH) {
        return (model) => {
            Operations.apply(model, Operations.replace(stemPath + '.content', content));
        };
    },
    editStemAndPreviewText(content, stemPath = STEM_PATH, previewTextPath = PREVIEW_TEXT_PATH) {
        return (model) => {
            StemActions.editStem(content, stemPath)(model);
            Operations.apply(model, Operations.replace(previewTextPath, toSimpleText(content)));
        };
    },
};
//# sourceMappingURL=stemActions.js.map