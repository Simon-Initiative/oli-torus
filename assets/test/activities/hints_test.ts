import { makeHint, ScoringStrategy } from 'components/activities/types';
import { Hints } from 'data/activities/model/hints';
import { dispatch } from 'utils/test_utils';

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
    expect(
      Hints.byPart(dispatch(model, Hints.addCognitiveHint(makeHint(''), '1')), '1').length,
    ).toBeGreaterThan(Hints.byPart(model, '1').length);
  });

  it('can edit a hint', () => {
    const newHintContent = makeHint('new content').content;
    const firstHint = Hints.byPart(model, '1')[0];
    expect(
      Hints.byPart(dispatch(model, Hints.setContent(firstHint.id, newHintContent)), '1')[0],
    ).toHaveProperty('content', newHintContent);
  });

  it('can remove a hint', () => {
    const firstHint = Hints.byPart(model, '1')[0];
    expect(Hints.byPart(dispatch(model, Hints.removeOne(firstHint.id)), '1')).toHaveLength(2);
  });
});
