import { HintActions } from 'components/activities/common/hints/authoring/hintActions';
import { getHints } from 'components/activities/common/hints/authoring/hintUtils';
import { HasParts, makeHint, ScoringStrategy } from 'components/activities/types';
import produce from 'immer';

const applyAction = (model: HasParts, action: any) => {
  return produce(model, (state) => action(state, () => undefined));
};

describe('authoring hints', () => {
  const model = {
    authoring: {
      parts: [
        {
          id: '1',
          hints: [makeHint(''), makeHint(''), makeHint('')],
          responses: [],
          scoringStrategy: {} as ScoringStrategy,
        },
      ],
    },
  };

  it('can add a cognitive hint before the end of the array', () => {
    expect(getHints(applyAction(model, HintActions.addHint(makeHint('')))).length).toBeGreaterThan(
      getHints(model).length,
    );
  });

  it('can edit a hint', () => {
    const newHintContent = makeHint('new content').content;
    const firstHint = getHints(model)[0];
    expect(
      getHints(applyAction(model, HintActions.editHint(firstHint.id, newHintContent)))[0],
    ).toHaveProperty('content', newHintContent);
  });

  it('can remove a hint', () => {
    const firstHint = getHints(model)[0];
    expect(
      getHints(
        applyAction(model, HintActions.removeHint(firstHint.id, '$.authoring.parts[0].hints')),
      ),
    ).toHaveLength(2);
  });
});
