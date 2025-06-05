export const contentTypes = [
  'Paragraph',
  'Group',
  'Bank',
  'Break',
  'Survey',
  'Report',
  'Alt',
  'A/B Test',
] as const;

export const questionTypes = [
  'Adaptive',
  'CATA',
  'DnD++',
  'DD',
  'Embed',
  'Upload',
  'Coding',
  'Hotspot',
  'Likert',
  'LogicLab',
  'Multi',
  'MCQ',
  'Order',
  'ResponseMulti',
  'Input',
  'Vlab',
] as const;

export type ActivityType = (typeof contentTypes)[number] | (typeof questionTypes)[number];