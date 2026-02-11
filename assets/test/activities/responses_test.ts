import { ScoringActions } from 'components/activities/common/authoring/actions/scoringActions';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import {
  ChoiceIdsToResponseId,
  HasChoices,
  HasParts,
  ScoringStrategy,
  makeChoice,
  makeFeedback,
  makeResponse,
} from 'components/activities/types';
import { getResponses, normalizeCustomScoringForPart } from 'data/activities/model/responses';
import { matchRule } from 'data/activities/model/rules';
import { dispatch } from 'utils/test_utils';

const DEFAULT_PART_ID = '1';

describe('responses', () => {
  const choice = makeChoice('a');
  const response = makeResponse(matchRule(choice.id), 1, '', true);
  const model: HasParts & HasChoices & { authoring: { targeted: ChoiceIdsToResponseId[] } } = {
    choices: [choice],
    authoring: {
      targeted: [[[choice.id], response.id]],
      parts: [
        {
          id: DEFAULT_PART_ID,
          responses: [response, makeResponse(matchRule('.*'), 0, '')],
          hints: [],
          scoringStrategy: {} as ScoringStrategy,
        },
      ],
    },
  };
  it('can edit feedback', () => {
    const newFeedbackContent = makeFeedback('new content').content;
    const firstFeedback = model.authoring.parts[0].responses[0];
    expect(
      dispatch(model, ResponseActions.editResponseFeedback(firstFeedback.id, newFeedbackContent))
        .authoring.parts[0].responses[0].feedback,
    ).toHaveProperty('content', newFeedbackContent);
  });

  it('can edit rules', () => {
    const response = getResponses(model)[0];
    const newModel = dispatch(model, ResponseActions.editRule(response.id, 'rule'));
    expect(getResponses(newModel)[0].rule).toBe('rule');
  });

  it('can remove responses', () => {
    const response = getResponses(model)[0];
    const newModel = dispatch(model, ResponseActions.removeResponse(response.id));
    expect(getResponses(newModel)).toHaveLength(1);
  });

  it('can remove targeted feedback (responses)', () => {
    const response = getResponses(model)[0];
    const newModel = dispatch(model, ResponseActions.removeTargetedFeedback(response.id));
    expect(newModel.authoring.parts[0].responses).toHaveLength(1);
    expect(newModel.authoring.targeted).toHaveLength(0);
  });

  describe('custom scoring normalization', () => {
    const buildModel = ({
      correctScore,
      targetedScores,
      customScoring,
      outOf = null,
    }: {
      correctScore: number;
      targetedScores: number[];
      customScoring: boolean;
      outOf?: number | null;
    }) => {
      const correct = makeResponse(matchRule('a'), correctScore, '', true);
      const targeted = targetedScores.map((score, index) =>
        makeResponse(matchRule(`t${index}`), score, ''),
      );
      const incorrect = makeResponse(matchRule('.*'), 0, '');

      return {
        customScoring,
        authoring: {
          parts: [
            {
              id: DEFAULT_PART_ID,
              responses: [correct, ...targeted, incorrect],
              hints: [],
              scoringStrategy: {} as ScoringStrategy,
              outOf,
              incorrectScore: 0,
            },
          ],
        },
      } as HasParts & { customScoring?: boolean };
    };

    it('updates correct and outOf when targeted score exceeds correct', () => {
      const model = buildModel({
        correctScore: 1,
        targetedScores: [2],
        customScoring: true,
        outOf: 1,
      });

      const targetedId = model.authoring.parts[0].responses[1].id;
      const updated = dispatch(model, ResponseActions.editResponseScore(targetedId, 4));

      expect(updated.authoring.parts[0].responses[0].score).toBe(4);
      expect(updated.authoring.parts[0].outOf).toBe(4);
    });

    it('keeps correct at least max targeted when correct score is edited lower', () => {
      const model = buildModel({
        correctScore: 5,
        targetedScores: [6],
        customScoring: true,
        outOf: 5,
      });

      const updated = dispatch(
        model,
        ScoringActions.editPartScore(DEFAULT_PART_ID, 2, 0, 'average'),
      );

      expect(updated.authoring.parts[0].responses[0].score).toBe(6);
      expect(updated.authoring.parts[0].outOf).toBe(6);
    });

    it('does nothing when custom scoring is not enabled', () => {
      const model = buildModel({
        correctScore: 1,
        targetedScores: [1],
        customScoring: false,
        outOf: null,
      });

      normalizeCustomScoringForPart(model, DEFAULT_PART_ID);

      expect(model.authoring.parts[0].responses[0].score).toBe(1);
      expect(model.authoring.parts[0].outOf).toBeNull();
    });
  });
});
