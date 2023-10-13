import { getCorrectResponse, getIncorrectResponse } from 'data/activities/model/responses';

export const ScoringActions = {
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

  editPartScore(partId: string, correctScore: number | null, incorrectScore: number | null) {
    return (model: any) => {
      const part = model.authoring.parts.find((p: any) => p.id === partId);
      if (!part) {
        console.warn('Could not set score for part', partId);
        return;
      }
      part.outOf = correctScore;
      part.incorrectScore = incorrectScore;

      // When we change the correct & incorrect scores, we also need to update the responses for the correct & incorrect answers
      if (correctScore !== null) {
        try {
          const correctResponse = getCorrectResponse(model, partId);
          if (correctResponse) {
            correctResponse.score = correctScore;
          }
        } catch (e) {
          console.warn('Could not find correct response for part', partId);
        }
      }

      if (incorrectScore !== null) {
        try {
          const incorrectResponse = getIncorrectResponse(model, partId);
          if (incorrectResponse) {
            incorrectResponse.score = incorrectScore;
          }
        } catch (e) {
          console.warn('Could not find incorrect response for part', partId);
        }
      }
    };
  },
};
