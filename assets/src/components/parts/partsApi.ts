export const observedAttributes = ['id', 'model', 'state'];

export const authoringObservedAttributes = ['editmode', 'configuremode', 'portal'];

export const customEvents = {
  onInit: 'init',
  onReady: 'ready',
  onSave: 'save',
  onSubmit: 'submit',
  onResize: 'resize',
  onGetData: 'getData',
  onSetData: 'setData',
};

export type PartAuthoringMode = 'expert' | 'simple';
