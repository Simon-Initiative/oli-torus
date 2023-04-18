import { Descendant } from 'slate';
import { HasPreviewText } from 'components/activities/types';
import { toSimpleText } from 'components/editing/slateUtils';
import { PREVIEW_TEXT_PATH, STEM_PATH } from 'data/activities/model/utils';
import { Operations } from 'utils/pathOperations';

export const StemActions = {
  editStem(content: Descendant[], stemPath = STEM_PATH) {
    return (model: any) => {
      Operations.apply(model, Operations.replace(stemPath + '.content', content));
    };
  },
  editStemAndPreviewText(
    content: Descendant[],
    stemPath = STEM_PATH,
    previewTextPath = PREVIEW_TEXT_PATH,
  ) {
    return (model: any & HasPreviewText) => {
      StemActions.editStem(content, stemPath)(model);
      Operations.apply(model, Operations.replace(previewTextPath, toSimpleText(content)));
    };
  },
};
