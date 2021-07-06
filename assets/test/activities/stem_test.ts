import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import { makeStem } from 'components/activities/types';
import { applyTestAction } from 'utils/test_utils';

describe('stem actions', () => {
  const model = {
    stem: makeStem(''),
    authoring: {
      previewText: '',
    },
  };

  it('can edit the stem', () => {
    const newStem = makeStem('new content');
    expect(applyTestAction(model, StemActions.editStem(newStem.content)).stem).toMatchObject({
      content: newStem.content,
    });
  });

  it('can edit the stem and preview text together', () => {
    const newStem = makeStem('new content');
    const newModel = applyTestAction(model, StemActions.editStemAndPreviewText(newStem.content));
    expect(newModel.stem).toMatchObject({
      content: newStem.content,
    });
    expect(newModel.authoring.previewText).toEqual('');
  });
});
