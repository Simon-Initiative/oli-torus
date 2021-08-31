import jp from 'jsonpath';

export const STEM_PATH = '$.stem';
export const getStem = (model: any, path = STEM_PATH) => jp.query(model, path)[0];

export const PREVIEW_TEXT_PATH = '$.authoring.previewText';
export const getPreviewText = (model: any, path = PREVIEW_TEXT_PATH): string =>
  jp.query(model, path)[0];
