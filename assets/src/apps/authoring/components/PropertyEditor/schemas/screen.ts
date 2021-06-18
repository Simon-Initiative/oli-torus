const screenSchema = {
  customCssClass: {
    type: 'string',
    options: { input_width: '500px' },
  },
  showCheckBtn: {
    type: 'boolean',
    format: 'checkbox',
    default: true,
  },
  width: { type: 'number' },
  height: { type: 'number' },
};

export default screenSchema;
