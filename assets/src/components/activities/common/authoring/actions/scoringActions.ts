import { ActivityLevelScoring, Part, Response, ScoringStrategy } from 'components/activities/types';
import {
  getIncorrectPoints,
  getOutOfPoints,
  multiHasCustomScoring,
} from 'data/activities/model/responses';

export const ScoringActions = {
  toggleActivityDefaultScoring() {
    // This toggles an activity-level default scoring flag, used for potentially multipart questions
    return (model: ActivityLevelScoring) => {
      // attribute may not exist on migrated qs; this will set it
      model.customScoring = !multiHasCustomScoring(model);

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
          // code part same as for single-part default scoring. Needed by TargetedFeedback
          // on part which doesn't know if it is part of single or multi part activity.
          part.outOf = null;
          part.incorrectScore = null;
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
    correctScore: number | null, // non-null if custom; null => set default scoring
    incorrectScore: number | null,
    scoringStrategy: string | undefined = undefined,
  ) {
    return (model: any) => {
      const part = model.authoring.parts.find((p: any) => p.id === partId);
      if (!part) {
        console.warn('Could not set score for part', partId);
        return;
      }

      // reject any change that violates consistency requirements
      const newCorrectPoints = correctScore || 1;
      const newIncorrectPoints = incorrectScore || 0;
      if (!(newCorrectPoints > newIncorrectPoints)) return;

      // fetch current special point values before modifying anything
      const oldCorrectPoints = getOutOfPoints(model, partId);
      const oldIncorrectPoints = getIncorrectPoints(model, partId);

      // update correct/incorrect scores in all responses, using score
      // match to hit alternate correct/incorrect in targeted feedbacks
      part.responses?.forEach((response: Response) => {
        if (response.score === oldCorrectPoints) response.score = newCorrectPoints;
        else if (response.score === oldIncorrectPoints) response.score = newIncorrectPoints;
        else {
          // Partial credit response. Ensure score remains within possibly new range
          if (correctScore === null) {
            // Going to default scoring. No more partial credit, so just treat
            // all non-correct as wrong.
            response.score = newIncorrectPoints;
          } else {
            // adjust score by scaling, preserving fraction of score range width
            const fraction =
              (response.score - oldIncorrectPoints) / (oldCorrectPoints - oldIncorrectPoints);
            response.score =
              newIncorrectPoints + fraction * (newCorrectPoints - newIncorrectPoints);
          }
        }
      });

      // update part-wide scoring params. nullish outOf codes for default scoring
      part.outOf = correctScore;
      part.incorrectScore = incorrectScore;
      if (scoringStrategy) {
        part.scoringStrategy = scoringStrategy;
      }
    };
  },
};
