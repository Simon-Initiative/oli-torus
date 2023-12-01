import { ActivityLevelScoring, Part, ScoringStrategy } from 'components/activities/types';
import { getCorrectResponse, getIncorrectResponse } from 'data/activities/model/responses';

export const ScoringActions = {
  toggleActivityDefaultScoring() {
    // This toggles an activity-level default scoring flag, currently only used for multi input questions.
    return (model: ActivityLevelScoring) => {
      model.customScoring = !model.customScoring;

      if (!model.customScoring) {
        // When going from custom to default, we need to reset the scores for each part to 1 or 0
        model.scoringStrategy = ScoringStrategy.average;
        model.authoring?.parts?.forEach((part: Part) => {
          const correctScore = part.outOf;
          part.outOf = 1;
          part.incorrectScore = 0;
          part.responses?.forEach((response) => {
            response.score = response.score === correctScore ? 1 : 0;
          });
        });
      }
    };
  },

  editActivityScoringStrategy(scoringStrategy: ScoringStrategy) {
    return (model: ActivityLevelScoring) => {
      // This changes an activity-level scoring strategy, currently only used for multi input questions.
      model.scoringStrategy = scoringStrategy;
    };
  },

  editPartScoringStrategy(partId: string, scoringStrategy: string) {
    return (model: any) => {
      const part = model.authoring.parts.find((p: any) => p.id === partId);
      if (!part) {
        console.warn('Could not set scoring strategy for part', partId);
        return;
      }
      part.scoringStrategy = scoringStrategy;
    };
  },

  editPartScore(
    partId: string,
    correctScore: number | null,
    incorrectScore: number | null,
    scoringStrategy: string | undefined = undefined,
  ) {
    return (model: any) => {
      const part = model.authoring.parts.find((p: any) => p.id === partId);
      if (!part) {
        console.warn('Could not set score for part', partId);
        return;
      }
      part.outOf = correctScore;
      part.incorrectScore = incorrectScore;

      if (scoringStrategy) {
        part.scoringStrategy = scoringStrategy;
      }

      // When we change the correct & incorrect scores, we also need to update the responses for the correct & incorrect answers

      try {
        const correctResponse = getCorrectResponse(model, partId);
        if (correctResponse) {
          correctResponse.score = correctScore ?? 1;
        }
      } catch (e) {
        console.warn('Could not find correct response for part', partId);
      }

      try {
        const incorrectResponse = getIncorrectResponse(model, partId);
        if (incorrectResponse) {
          incorrectResponse.score = incorrectScore ?? 0;
        }
      } catch (e) {
        console.warn('Could not find incorrect response for part', partId);
      }
    };
  },
};
