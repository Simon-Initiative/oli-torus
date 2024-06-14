import { ActivityLevelScoring, Part, Response, ScoringStrategy } from 'components/activities/types';
import {
  getCorrectResponse,
  getIncorrectResponse,
  getOutOfPoints,
} from 'data/activities/model/responses';

// Migrated qs may have non-default point values but no customScoring attribute. To allow for this,
// this method should be used rather than checking attribute. Attribute will get set if toggled
export const usesCustomScoring = (model: ActivityLevelScoring) =>
  model.customScoring ||
  model.authoring.parts.some((part: Part) => part.responses.some((r: Response) => r.score > 1));

export const ScoringActions = {
  toggleActivityDefaultScoring() {
    // This toggles an activity-level default scoring flag, currently only used for multi input questions.
    return (model: ActivityLevelScoring) => {
      // attribute may not exist on migrated qs; this will set it
      model.customScoring = !usesCustomScoring(model);

      if (model.customScoring) {
        // going from default to custom, so all responses should already be 1 or 0.
        model.authoring?.parts?.forEach((part: Part) => {
          part.outOf = 1;
        });
      } else {
        // When going from custom to default, we need to reset the scores for each part to 1 or 0
        model.scoringStrategy = ScoringStrategy.average;
        model.authoring?.parts?.forEach((part: Part) => {
          const oldCorrectScore = getOutOfPoints(model, part.id);
          part.outOf = 1;
          part.incorrectScore = 0;
          part.responses?.forEach((response) => {
            response.score = response.score === oldCorrectScore ? 1 : 0;
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
      // outOf attribute may not exist on migrated questions
      const oldCorrectScore = getOutOfPoints(model, part.id);
      part.outOf = correctScore;
      part.incorrectScore = incorrectScore;

      if (scoringStrategy) {
        part.scoringStrategy = scoringStrategy;
      }

      // if changing to default, reset the scores for each part to 1 or 0
      if (part.outOf == null) {
        model.authoring?.parts?.forEach((part: Part) => {
          part.responses?.forEach((response) => {
            response.score = response.score === oldCorrectScore ? 1 : 0;
          });
        });
      } else {
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
      }
    };
  },
};
