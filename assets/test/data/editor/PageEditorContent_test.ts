import * as Immutable from 'immutable';
import { Model } from 'data/content/model/elements/factories';
import {
  ResourceContent,
  createDefaultStructuredContent,
  createGroup,
} from 'data/content/resource';
import { PageEditorContent } from 'data/editor/PageEditorContent';
import guid from 'utils/guid';

describe('PageEditorContent', () => {
  const createExampleContent = () =>
    createDefaultStructuredContent([
      Model.h1('A great example'),
      Model.p('This is some example content'),
      Model.image('https://example.com/someimage.png'),
    ]);

  const createNestedGroupContent = () =>
    createDefaultStructuredContent([
      Model.h1('Learn by doing'),
      Model.p('This is some "learn by doing" group content'),
    ]);

  const createDefaultPageEditorContent = () => {
    const exampleContent = createExampleContent();
    const nestedGroupContent = createNestedGroupContent();
    const exampleGroup = createGroup('none', Immutable.List().push(nestedGroupContent));
    const doesntExist = createDefaultStructuredContent([
      Model.h1('wont be added to the content'),
      Model.p('This is some content that doesnt exist'),
    ]);

    const model = Immutable.List<ResourceContent>().push(exampleContent).push(exampleGroup);
    const pageEditorContent = new PageEditorContent({
      version: '0.1.0',
      model,
      trigger: undefined,
    });

    return {
      pageEditorContent,
      exampleContent,
      nestedGroupContent,
      exampleGroup,
      doesntExist,
    };
  };

  it('find', () => {
    const { pageEditorContent, exampleContent, exampleGroup, doesntExist } =
      createDefaultPageEditorContent();

    expect(pageEditorContent.find(exampleContent.id)).toEqual(exampleContent);
    expect(pageEditorContent.find(exampleGroup.id)).toEqual(exampleGroup);
    expect(pageEditorContent.find(doesntExist.id)).toEqual(undefined);
  });

  it('findIndex', () => {
    const { pageEditorContent, exampleContent, nestedGroupContent, exampleGroup, doesntExist } =
      createDefaultPageEditorContent();

    expect(pageEditorContent.findIndex((c) => c.id === exampleContent.id)).toEqual([0]);
    expect(pageEditorContent.findIndex((c) => c.id === exampleGroup.id)).toEqual([1]);
    expect(pageEditorContent.findIndex((c) => c.id === nestedGroupContent.id)).toEqual([1, 0]);
    expect(pageEditorContent.findIndex((c) => c.id === doesntExist.id)).toEqual([]);
  });

  it('delete', () => {
    const defaultPageEditorContent = createDefaultPageEditorContent();
    const { exampleContent, exampleGroup } = defaultPageEditorContent;
    let { pageEditorContent } = defaultPageEditorContent;

    expect(pageEditorContent.find(exampleContent.id)).toEqual(exampleContent);
    expect(pageEditorContent.find(exampleGroup.id)).toEqual(exampleGroup);

    pageEditorContent = pageEditorContent.delete(exampleContent.id);

    expect(pageEditorContent.find(exampleContent.id)).toEqual(undefined);
    expect(pageEditorContent.find(exampleGroup.id)).toEqual(exampleGroup);

    pageEditorContent = pageEditorContent.delete(exampleGroup.id);

    expect(pageEditorContent.find(exampleContent.id)).toEqual(undefined);
    expect(pageEditorContent.find(exampleGroup.id)).toEqual(undefined);
  });

  it('insertAt', () => {
    const defaultPageEditorContent = createDefaultPageEditorContent();
    const { exampleGroup, doesntExist } = defaultPageEditorContent;
    let { pageEditorContent } = defaultPageEditorContent;

    pageEditorContent = pageEditorContent.insertAt([1, 0], doesntExist);

    const doesExist = doesntExist;

    expect(pageEditorContent.findIndex((c) => c.id === doesExist.id)).toEqual([1, 0]);

    // add an item with an index that doesnt exist, item should be added
    // at the further valid position
    const newItem = createDefaultStructuredContent([Model.h1('new item 1')]);

    pageEditorContent = pageEditorContent.insertAt([0, 1, 2, 3], newItem);

    expect(pageEditorContent.findIndex((c) => c.id === newItem.id)).toEqual([0]);

    // delete the group and try to insert into it, item should be added
    // at the further valid position
    const newItem2 = createDefaultStructuredContent([Model.h1('new item 2')]);

    pageEditorContent = pageEditorContent.delete(exampleGroup.id);
    pageEditorContent = pageEditorContent.insertAt([1, 1], newItem2);

    expect(pageEditorContent.findIndex((c) => c.id === newItem2.id)).toEqual([1]);

    // add an item to the end
    const last = createDefaultStructuredContent([Model.h1('last item')]);
    pageEditorContent = pageEditorContent.insertAt([3], last);

    expect(pageEditorContent.findIndex((c) => c.id === last.id)).toEqual([3]);
  });

  it('replaceAt', () => {
    const defaultPageEditorContent = createDefaultPageEditorContent();
    const { exampleContent, doesntExist } = defaultPageEditorContent;
    let { pageEditorContent } = defaultPageEditorContent;

    pageEditorContent = pageEditorContent.replaceAt([0], doesntExist);

    const replacedWith = doesntExist;

    expect(pageEditorContent.findIndex((c) => c.id === replacedWith.id)).toEqual([0]);
    expect(pageEditorContent.findIndex((c) => c.id === exampleContent.id)).toEqual([]);

    // replace an item with an index that doesnt exist, item should not be added
    // at all
    const newItem = createDefaultStructuredContent([Model.h1('new item 1')]);

    pageEditorContent = pageEditorContent.replaceAt([0, 1, 2, 3], newItem);

    expect(pageEditorContent.findIndex((c) => c.id === newItem.id)).toEqual([]);

    // try to replace another item that is out of bounds
    const last = createDefaultStructuredContent([Model.h1('last item')]);
    pageEditorContent = pageEditorContent.replaceAt([3], last);

    expect(pageEditorContent.findIndex((c) => c.id === last.id)).toEqual([]);
  });

  it('updateContentItem', () => {
    const defaultPageEditorContent = createDefaultPageEditorContent();
    const { exampleContent } = defaultPageEditorContent;
    let { pageEditorContent } = defaultPageEditorContent;

    const updatedExampleContent = {
      ...exampleContent,
      children: [...exampleContent.children, Model.p('here we added some content')],
    };

    pageEditorContent = pageEditorContent.updateContentItem(
      updatedExampleContent.id,
      updatedExampleContent,
    );

    expect(pageEditorContent.find(exampleContent.id)).toEqual(updatedExampleContent);
  });

  it('updateAll', () => {
    const defaultPageEditorContent = createDefaultPageEditorContent();
    const { exampleContent, nestedGroupContent } = defaultPageEditorContent;
    let { pageEditorContent } = defaultPageEditorContent;

    pageEditorContent = pageEditorContent.updateAll((c: ResourceContent) =>
      c.type === 'content' ? { ...c, children: [Model.h1('replaced')] } : c,
    );

    expect((pageEditorContent.find(exampleContent.id) as any).children[0].children[0].text).toEqual(
      'replaced',
    );

    expect(
      (pageEditorContent.find(nestedGroupContent.id) as any).children[0].children[0].text,
    ).toEqual('replaced');
  });

  it('flatten', () => {
    const { pageEditorContent, exampleContent, exampleGroup, nestedGroupContent } =
      createDefaultPageEditorContent();

    expect(pageEditorContent.flatten().toArray()).toEqual([
      exampleContent,
      exampleGroup,
      nestedGroupContent,
    ]);
  });

  it('flattenedIndex', () => {
    const { pageEditorContent, exampleContent } = createDefaultPageEditorContent();

    expect(pageEditorContent.flattenedIndex(exampleContent.id)).toEqual(0);
  });

  it('size', () => {
    const { pageEditorContent } = createDefaultPageEditorContent();

    expect(pageEditorContent.count()).toEqual(3);
  });

  it('first', () => {
    const { pageEditorContent, exampleContent } = createDefaultPageEditorContent();

    expect(pageEditorContent.first()).toEqual(exampleContent);
  });

  it('last', () => {
    const { pageEditorContent, nestedGroupContent } = createDefaultPageEditorContent();

    expect(pageEditorContent.last()).toEqual(nestedGroupContent);
  });

  it('toPersistence', () => {
    const { pageEditorContent } = createDefaultPageEditorContent();

    expect(pageEditorContent.toPersistence()).toEqual({
      version: '0.1.0',
      model: [
        {
          children: [
            {
              children: [
                {
                  text: 'A great example',
                },
              ],
              id: expect.any(String),
              type: 'h1',
            },
            {
              children: [
                {
                  text: 'This is some example content',
                },
              ],
              id: expect.any(String),
              type: 'p',
            },
            {
              children: [
                {
                  text: '',
                },
              ],
              display: 'block',
              id: expect.any(String),
              src: 'https://example.com/someimage.png',
              type: 'img',
            },
          ],
          id: expect.any(String),
          textDirection: 'ltr',
          editor: 'slate',
          type: 'content',
        },
        {
          children: [
            {
              children: [
                {
                  children: [
                    {
                      text: 'Learn by doing',
                    },
                  ],
                  id: expect.any(String),
                  type: 'h1',
                },
                {
                  children: [
                    {
                      text: 'This is some "learn by doing" group content',
                    },
                  ],
                  id: expect.any(String),
                  type: 'p',
                },
              ],
              id: expect.any(String),
              textDirection: 'ltr',
              editor: 'slate',
              type: 'content',
            },
          ],
          id: expect.any(String),
          layout: 'vertical',
          purpose: 'none',
          type: 'group',
        },
      ],
    });
  });

  it('fromPersistence', () => {
    const nestedGuid = guid();
    const pageEditorContent = PageEditorContent.fromPersistence({
      version: '0.1.0',
      model: [
        {
          children: [
            {
              children: [
                {
                  text: 'A great example',
                },
              ],
              id: guid(),
              type: 'h1',
            },
            {
              children: [
                {
                  text: 'This is some example content',
                },
              ],
              id: guid(),
              type: 'p',
            },
            {
              children: [
                {
                  text: '',
                },
              ],
              display: 'block',
              id: guid(),
              src: 'https://example.com/someimage.png',
              type: 'img',
            },
          ],
          id: guid(),
          purpose: 'none',
          type: 'content',
        },
        {
          children: [
            {
              children: [
                {
                  children: [
                    {
                      text: 'Learn by doing',
                    },
                  ],
                  id: guid(),
                  type: 'h1',
                },
                {
                  children: [
                    {
                      text: 'This is some "learn by doing" group content',
                    },
                  ],
                  id: guid(),
                  type: 'p',
                },
              ],
              id: nestedGuid,
              purpose: 'none',
              type: 'content',
            },
          ],
          id: guid(),
          layout: 'vertical',
          purpose: 'didigetthis',
          type: 'group',
        },
      ],
    });

    expect(pageEditorContent.version).toEqual('0.1.0');
    expect(pageEditorContent.model.size).toEqual(2);
    expect((pageEditorContent.find(nestedGuid) as any).children.length).toEqual(2);
    expect((pageEditorContent.find(nestedGuid) as any).children[1].children[0]).toEqual({
      text: 'This is some "learn by doing" group content',
    });
  });
});
