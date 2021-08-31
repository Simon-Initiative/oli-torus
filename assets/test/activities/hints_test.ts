import { HintActions } from 'components/activities/common/hints/authoring/hintActions';
import { getHints } from 'components/activities/common/hints/authoring/hintUtils';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { makeHint, ScoringStrategy } from 'components/activities/types';
import { dispatch } from 'utils/test_utils';

describe('authoring hints', () => {
  const model = {
    authoring: {
      parts: [
        {
          id: DEFAULT_PART_ID,
          hints: [makeHint(''), makeHint(''), makeHint('')],
          responses: [],
          scoringStrategy: {} as ScoringStrategy,
        },
      ],
    },
  };

  it('can add a cognitive hint before the end of the array', () => {
    expect(
      getHints(
        dispatch(model, HintActions.addCognitiveHint(makeHint(''), DEFAULT_PART_ID)),
        DEFAULT_PART_ID,
      ).length,
    ).toBeGreaterThan(getHints(model, DEFAULT_PART_ID).length);
  });

  it('can edit a hint', () => {
    const newHintContent = makeHint('new content').content;
    const firstHint = getHints(model, DEFAULT_PART_ID)[0];
    expect(
      getHints(
        dispatch(model, HintActions.editHint(firstHint.id, newHintContent, DEFAULT_PART_ID)),
        DEFAULT_PART_ID,
      )[0],
    ).toHaveProperty('content', newHintContent);
  });

  it('can remove a hint', () => {
    const firstHint = getHints(model, DEFAULT_PART_ID)[0];
    expect(
      getHints(
        dispatch(
          model,
          HintActions.removeHint(firstHint.id, '$.authoring.parts[0].hints', DEFAULT_PART_ID),
        ),
        DEFAULT_PART_ID,
      ),
    ).toHaveLength(2);
  });
});
