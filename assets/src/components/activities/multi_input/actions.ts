import { RichText, HasPreviewText, HasStems } from 'components/activities/types';
import { toSimpleText } from 'data/content/text';

export const MultiInputActions = {
  editStem(content: RichText, index: number) {
    return (model: HasStems) => {
      model.stems[index].content = content;
    };
  },
  editStemAndPreviewText(content: RichText, index: number) {
    return (model: HasStems & HasPreviewText) => {
      MultiInputActions.editStem(content, index);
      // TODO: Intersperse something like <Dropdown> for the input after the stem
      model.authoring.previewText = model.stems
        .map((stem) => toSimpleText({ children: stem.content.model }))
        .join('');
    };
  },
};
