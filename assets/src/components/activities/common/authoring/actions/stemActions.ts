import { PREVIEW_TEXT_PATH, STEM_PATH } from 'components/activities/common/authoring/actions/utils';
import { HasPreviewText, RichText } from 'components/activities/types';
import { toSimpleText } from 'data/content/text';
import { Operations } from 'utils/pathOperations';

export const StemActions = {
  editStem(content: RichText, stemPath = STEM_PATH) {
    return (model: any) => {
      Operations.apply(model, Operations.replace(stemPath + '.content', content));
    };
  },
  editStemAndPreviewText(
    content: RichText,
    stemPath = STEM_PATH,
    previewTextPath = PREVIEW_TEXT_PATH,
  ) {
    return (model: any & HasPreviewText) => {
      StemActions.editStem(content, stemPath)(model);
      Operations.apply(
        model,
        Operations.replace(previewTextPath, toSimpleText({ children: content.model })),
      );
    };
  },
};
