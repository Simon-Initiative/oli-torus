import Ajv from 'ajv';
import fs from 'fs';
import path from 'path';
import { Model } from 'data/content/model/elements/factories';

const directory = path.resolve(__dirname, '../../../../priv/schemas/v0-1-0');
const ajv = new Ajv({ strict: false, allErrors: true, logger: false });
for (const name of fs.readdirSync(directory).filter((name) => name.endsWith('.json'))) {
  ajv.addSchema(JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8')));
}
const validate = ajv.getSchema(
  'http://torus.oli.cmu.edu/schemas/v0-1-0/page-content-basic.schema.json',
)!;
const samples = {
  paragraph: Model.p(),
  paragraphImage: Model.p([Model.image('image.png')]),
  h1: Model.h1(),
  h2: Model.h2(),
  orderedList: Model.ol(),
  unorderedList: Model.ul(),
  descriptionList: Model.dl(),
  table: Model.table([Model.tr([Model.th(''), Model.td(''), Model.tc('')])]),
  image: Model.image(),
  inlineImage: Model.p([Model.imageInline()]),
  youtube: Model.youtube(),
  video: Model.video(),
  audio: Model.audio(),
  iframe: Model.webpage(),
  callout: Model.callout(),
  inlineCallout: Model.p([Model.calloutInline()]),
  conjugation: Model.conjugation(),
  dialog: { ...Model.dialog(), lines: [Model.dialogLine('speaker')] },
  figure: Model.figure(),
  foreign: Model.p([Model.foreign()]),
  formula: Model.formula(),
  inlineFormula: Model.p([Model.formulaInline()]),
  link: Model.p([Model.link('https://example.com')]),
  commandButton: Model.p([Model.commandButton()]),
  pageLink: Model.page_link(1),
  citation: Model.p([Model.cite('citation', 1)]),
  blockquote: Model.blockquote(),
  codeV1: Model.codeV1(),
  codeV2: Model.code(),
  ecl: Model.ecl(),
  popup: Model.p([Model.popup()]),
  definition: Model.definition({
    pronunciation: Model.definitionPronunciation(),
    translations: [Model.definitionTranslation()],
  }),
  definitionDraft: Model.definition(),
  trigger: Model.trigger(),
};

// These factory-produced examples are also consumed by the server's JSV tests.
const fixtures = JSON.parse(
  fs.readFileSync(
    path.resolve(__dirname, '../../../../test/support/fixtures/basic_page_elements.json'),
    'utf8',
  ),
);
const withoutIds = (value: any): any => {
  if (Array.isArray(value)) return value.map(withoutIds);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value)
        .filter(([key]) => key !== 'id')
        .map(([key, child]) => [key, withoutIds(child)]),
    );
  }
  return value;
};

describe('Basic Page JSON contract', () => {
  test.each(Object.entries(samples))('accepts factory output: %s', (name, element) => {
    const page = { version: '0.1.0', model: [{ type: 'content', children: [element] }] };
    expect(validate(page)).toBe(true);
    expect(withoutIds(fixtures[name])).toEqual(withoutIds(element));
  });
  test.each([
    ['untyped element', {}],
    ['unknown type disguised as text', { type: 'unknown', text: 'bypass' }],
    ['video source scalar', { type: 'video', src: [123] }],
    ['video source missing content type', { type: 'video', src: [{ url: 'video.mp4' }] }],
    [
      'invalid table nesting',
      { type: 'table', children: [{ type: 'p', children: [{ text: '' }] }] },
    ],
    [
      'invalid content trigger context',
      { type: 'trigger', trigger_type: 'page', prompt: '', children: [{ text: '' }] },
    ],
  ])('rejects malformed content: %s', (_name, element) => {
    expect(validate({ version: '0.1.0', model: [{ type: 'content', children: [element] }] })).toBe(
      false,
    );
  });
});
