import { validateEditorContentValue } from 'components/editing/editor/Editor';
import { Model } from 'data/content/model/elements/factories';
import { expectAnyId } from './normalize-test-utils';
import { Descendant } from 'slate';

describe('validateEditorContentValue', () => {
  it('should return default value for undefined value', () => {
    const value = undefined;
    const expectedOutput = [Model.p()];
    expect(validateEditorContentValue(value)).toEqual(expectAnyId(expectedOutput));
  });

  it('should return default value for empty array value', () => {
    const value: any[] = [];
    const expectedOutput = [Model.p()];
    expect(validateEditorContentValue(value)).toEqual(expectAnyId(expectedOutput));
  });

  it('should return default value for non-array value', () => {
    const value = 'not an array';
    const expectedOutput = [Model.p()];
    expect(validateEditorContentValue(value)).toEqual(expectAnyId(expectedOutput));
  });

  it('should return model property value for object with model property', () => {
    const value = { model: [{ type: 'p', id: '1', children: [{ text: 'Hello, world!' }] }] };
    const expectedOutput = value.model as Descendant[];
    expect(validateEditorContentValue(value)).toEqual(expectAnyId(expectedOutput));
  });

  it('should return input array value for valid array value', () => {
    const value = [{ type: 'p', id: '1', children: [{ text: 'Hello, world!' }] }];
    const expectedOutput = value as Descendant[];;
    expect(validateEditorContentValue(value)).toEqual(expectAnyId(expectedOutput));
  });
});
