export const ACTIVITY_TYPE = {
  paragraph: { label: 'Is Paragraph', 'data-to': 'paragraph', type: 'Paragraph' },
  group: { label: 'Is Group', 'data-to': 'group', type: 'Group' },
  bank: { label: 'Is Bank', 'data-to': 'bank', type: 'Bank' },
  break: { label: 'Is Break', 'data-to': 'break', type: 'Break' },
  survey: { label: 'Is Survey', 'data-to': 'survey', type: 'Survey' },
  report: { label: 'Is Report', 'data-to': 'report', type: 'Report' },
  alt: { label: 'Is Alt', 'data-to': 'alt', type: 'Alt' },
  ab_test: { label: 'Is A/B Test', 'data-to': 'a-b-test', type: 'A/B Test' },

  adaptive: { label: 'Adaptive Activity', 'data-to': 'oli_adaptive', type: 'Adaptive' },
  cata: { label: 'Is CATA', 'data-to': 'cata', type: 'CATA' },
  dnd: { label: 'Custom Drag and Drop', 'data-to': 'oli_custom_dnd', type: 'DnD++' },
  dd: { label: 'Directed Discussion', 'data-to': 'oli_directed_discussion', type: 'DD' },
  embed: { label: 'OLI Embedded', 'data-to': 'oli_embedded', type: 'Embed' },
  file_aupload: { label: 'File Upload', 'data-to': 'oli_file_upload', type: 'Upload' },
  coding: { label: 'Image Coding', 'data-to': 'oli_image_coding', type: 'Coding' },
  hotspot: { label: 'Image Hotspot', 'data-to': 'oli_image_hotspot', type: 'Hotspot' },
  likert: { label: 'Likert', 'data-to': 'oli_likert', type: 'Likert' },
  logic_lab: { label: 'AProS LogicLab', 'data-to': 'oli_logic_lab', type: 'LogicLab' },
  multi: { label: 'Multi Input', 'data-to': 'oli_multi_input', type: 'Multi' },
  mcq: { label: 'Is MCQ', 'data-to': 'mcq', type: 'MCQ' },
  order: { label: 'Is Order', 'data-to': 'order', type: 'Order' },
  response_multi: {
    label: 'ResponseMulti Input',
    'data-to': 'oli_response_multi',
    type: 'ResponseMulti',
  },
  input: { label: 'Is Input', 'data-to': 'input', type: 'Input' },
  vlab: { label: 'Virtual Lab', 'data-to': 'oli_vlab', type: 'Vlab' },
} as const;

export type ActivityType = keyof typeof ACTIVITY_TYPE;
