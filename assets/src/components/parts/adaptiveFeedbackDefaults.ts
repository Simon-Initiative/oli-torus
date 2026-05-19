export const DEFAULT_ADAPTIVE_CORRECT_FEEDBACK = "That's correct!";
export const DEFAULT_ADAPTIVE_INCORRECT_FEEDBACK = "That's incorrect";

export const withAdaptiveFeedbackDefaults = <T extends Record<string, any>>(custom: T): T => ({
  ...custom,
  correctFeedback:
    typeof custom.correctFeedback === 'string' && custom.correctFeedback.trim().length > 0
      ? custom.correctFeedback
      : DEFAULT_ADAPTIVE_CORRECT_FEEDBACK,
  incorrectFeedback:
    typeof custom.incorrectFeedback === 'string' && custom.incorrectFeedback.trim().length > 0
      ? custom.incorrectFeedback
      : DEFAULT_ADAPTIVE_INCORRECT_FEEDBACK,
});
