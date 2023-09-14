import { Model, removeUndefined } from 'data/content/model/elements/factories';

describe('factories', () => {
  describe('removeUndefined', () => {
    it('Should remove undefined properties', () => {
      // removeUndefined({a: 1, b: undefined}) = {a: 1}
      expect(removeUndefined({ a: 1, b: undefined })).toEqual({ a: 1 });
    });
    it('Should not do anything with no undefined', () => {
      expect(removeUndefined({ a: 1, b: 2 })).toEqual({ a: 1, b: 2 });
    });

    it('Should keep nulls', () => {
      expect(removeUndefined({ a: 1, b: null })).toEqual({ a: 1, b: null });
    });
  });

  describe('create', () => {
    it('Should create an h1', () => {
      expect(Model.h1('text')).toEqual({
        type: 'h1',
        id: expect.any(String),
        children: [{ text: 'text' }],
      });
    });
    it('Should create an h1', () => {
      expect(Model.h1('text')).toEqual({
        type: 'h1',
        id: expect.any(String),
        children: [{ text: 'text' }],
      });
    });
    it('Should create a webpage with no src attribute', () => {
      expect(Model.webpage()).toEqual({
        type: 'iframe',
        id: expect.any(String),
        children: [{ text: '' }],
      });
    });
  });
});
