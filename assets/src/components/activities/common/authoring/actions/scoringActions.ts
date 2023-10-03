export const ScoringActions = {
  editPartScore(partId: string, correctScore: number | null, incorrectScore: number | null) {
    return (model: any) => {
      const part = model.authoring.parts.find((p: any) => p.id === partId);
      if (!part) {
        console.warn('Could not set score for part', partId);
        return;
      }
      part.outOf = correctScore;
      part.incorrectScore = incorrectScore;
    };
  },
};
