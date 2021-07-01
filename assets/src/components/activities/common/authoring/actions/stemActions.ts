import { HasPreviewText, HasStem, RichText } from 'components/activities/types';
import { toSimpleText } from 'data/content/text';

export const StemActions = {
  editStem(content: RichText) {
    return (model: HasStem) => {
      model.stem.content = content;
    };
  },
  editStemAndPreviewText(content: RichText) {
    return (model: HasStem & HasPreviewText) => {
      StemActions.editStem(content)(model);
      model.authoring.previewText = toSimpleText({ children: content.model });
    };
  },
};
