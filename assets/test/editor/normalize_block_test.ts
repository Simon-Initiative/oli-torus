import { Model } from 'data/content/model/elements/factories';
import { ImageBlock, Inline, Paragraph } from 'data/content/model/elements/types';
import { expectAnyId, expectConsoleMessage, runNormalizer } from './normalize-test-utils';

describe('editor / block normalizer', () => {
  it('Should allow text nodes in paragraphs', () => {
    const original = [Model.p([{ text: 'Hello There' }])];
    const expected = expectAnyId([Model.p([{ text: 'Hello There' }])]);
    const { editor } = runNormalizer(original);
    expect(editor.children).toEqual(expected);
  });

  it('Should allow inline nodes in paragraphs', () => {
    const inlineNodes: (Inline | ImageBlock)[] = [
      Model.imageInline('foo.png'),
      Model.image('foo.png'), // this is block, but allowed.
      Model.commandButton(),
      Model.popup(),
      Model.cite('foo', 1),
      Model.formulaInline(),
      Model.foreign(),
      Model.calloutInline(),
    ];
    for (const node of inlineNodes) {
      const original = [Model.p([node])];
      const { editor } = runNormalizer(original);
      expect((editor.children[0] as Paragraph).children).toContainEqual(node);
    }
  });

  it('Should remove nested paragraphs, but keep content', () => {
    const original = [Model.p([Model.p('Hi There '), Model.p('Goodbye')] as any)];
    const expected = expectAnyId([Model.p('Hi There Goodbye')]);
    const { editor } = runNormalizer(original);
    expect(editor.children).toEqual(expected);
  });

  it('Should remove invalid block elements (code in p)', () => {
    const original = [Model.p([{ text: 'Hi There' }, Model.code('Goodbye')] as any)];
    const expected = expectAnyId([Model.p('Hi There')]);
    const { editor } = runNormalizer(original);
    expect(editor.children).toEqual(expected);
  });

  it('Should remove invalid block elements (li in p)', () => {
    const original = [Model.p([Model.li('Hi There')] as any)];
    const expected = expectAnyId([Model.p('Hi There')]);
    const { editor } = runNormalizer(original);
    expect(editor.children).toEqual(expected);
  });

  it('Should not allow non top-level block elements in the root', () => {
    const original = [Model.dialogLine('Kenobi', 'Hello There')];
    const expected = expectAnyId([Model.p('Hello There')]);
    const { editor, consoleWarnCalls } = runNormalizer(original as any);
    expectConsoleMessage(
      'Normalizing content: Unwrapping top level block node dialog_line',
      consoleWarnCalls,
    );
    expect(editor.children).toEqual(expected);
  });

  it('should handle code special case', () => {
    const original = [
      {
        ...Model.code(),
        children: [Model.p('Inner Paragraph')],
      },
    ];
    const expected = expectAnyId([Model.p()]);
    const { editor } = runNormalizer(original as any);

    expect(editor.children).toEqual(expected);
  });
});
