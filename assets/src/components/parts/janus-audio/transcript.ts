export const getTranscriptFileFromModel = (model: any): string => {
  if (typeof model?.transcript?.transcriptFile === 'string') {
    return model.transcript.transcriptFile;
  }
  if (typeof model?.subtitles?.transcriptFile === 'string') {
    return model.subtitles.transcriptFile;
  }
  if (typeof model?.transcriptFile === 'string') {
    return model.transcriptFile;
  }
  return '';
};

export const getTranscriptTextFromModel = (model: any): string => {
  if (typeof model?.transcript?.transcriptText === 'string') {
    return model.transcript.transcriptText;
  }
  if (typeof model?.transcriptText === 'string') {
    return model.transcriptText;
  }
  return '';
};

export const hasTranscriptFromModel = (model: any): boolean => {
  return (
    getTranscriptFileFromModel(model).trim().length > 0 ||
    getTranscriptTextFromModel(model).trim().length > 0
  );
};
