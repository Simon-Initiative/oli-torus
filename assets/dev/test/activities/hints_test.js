import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { makeHint } from 'components/activities/types';
import { Hints } from 'data/activities/model/hints';
import { dispatch } from 'utils/test_utils';
describe('authoring hints', () => {
    const model = {
        authoring: {
            parts: [
                {
                    id: DEFAULT_PART_ID,
                    hints: [makeHint(''), makeHint(''), makeHint('')],
                    responses: [],
                    scoringStrategy: {},
                },
            ],
        },
    };
    it('can add a cognitive hint before the end of the array', () => {
        expect(Hints.byPart(dispatch(model, Hints.addCognitiveHint(makeHint(''), DEFAULT_PART_ID)), DEFAULT_PART_ID).length).toBeGreaterThan(Hints.byPart(model, DEFAULT_PART_ID).length);
    });
    it('can edit a hint', () => {
        const newHintContent = makeHint('new content').content;
        const firstHint = Hints.byPart(model, DEFAULT_PART_ID)[0];
        expect(Hints.byPart(dispatch(model, Hints.setContent(firstHint.id, newHintContent)), DEFAULT_PART_ID)[0]).toHaveProperty('content', newHintContent);
    });
    it('can remove a hint', () => {
        const firstHint = Hints.byPart(model, DEFAULT_PART_ID)[0];
        expect(Hints.byPart(dispatch(model, Hints.removeOne(firstHint.id)), DEFAULT_PART_ID)).toHaveLength(2);
    });
});
//# sourceMappingURL=hints_test.js.map