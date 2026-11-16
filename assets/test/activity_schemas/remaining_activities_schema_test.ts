import Ajv from 'ajv';
import fs from 'fs';
import path from 'path';
import { registerCreationFunc } from 'components/activities/creation';
import { ImageHotspotActions } from 'components/activities/image_hotspot/actions';
import { makeHotspot } from 'components/activities/image_hotspot/schema';
import { defaultImageHotspotModel } from 'components/activities/image_hotspot/utils';
import { LabActivity } from 'components/activities/logic_lab/LogicLabModelSchema';
// Load real registration callbacks while isolating browser component registration.
import 'components/activities/logic_lab/authoring-entry';
import 'components/activities/lti_external_tool/authoring-entry';
import { OliEmbeddedActions } from 'components/activities/oli_embedded/actions';
import { defaultEmbeddedModel } from 'components/activities/oli_embedded/utils';
import { VlabActions } from 'components/activities/vlab/actions';
import { VlabInputType } from 'components/activities/vlab/schema';
import { defaultModel as defaultVlab } from 'components/activities/vlab/utils';
import guid from 'utils/guid';

jest.mock('utils/guid', () => ({ __esModule: true, default: jest.fn() }));
jest.mock('components/activities/creation', () => ({ registerCreationFunc: jest.fn() }));
jest.mock('components/activities/logic_lab/LogicLabAuthoring', () => ({}));
jest.mock('components/activities/logic_lab/LogicLabDelivery', () => ({}));
jest.mock('components/activities/lti_external_tool/LTIExternalToolAuthoring', () => ({}));
jest.mock('components/activities/lti_external_tool/LTIExternalToolDelivery', () => ({}));

const uri = 'http://torus.oli.cmu.edu/schemas/v0-1-0/';
const directory = path.resolve(__dirname, '../../../priv/schemas/v0-1-0');
const activitiesDirectory = path.resolve(__dirname, '../../src/components/activities');
const fixturePath = path.resolve(
  __dirname,
  '../../../test/support/fixtures/remaining_activity_models.json',
);
const ajv = new Ajv({ strict: false, allErrors: true, logger: false });
for (const name of fs.readdirSync(directory).filter((name) => name.endsWith('.json'))) {
  ajv.addSchema(JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8')));
}
const slugs: Record<string, string> = {
  'image-hotspot': 'oli_image_hotspot',
  'oli-embedded': 'oli_embedded',
  'lti-external-tool': 'lti_external_tool',
  'logic-lab': 'oli_logic_lab',
  vlab: 'oli_vlab',
};
const valid = (name: string, model: unknown) => ajv.getSchema(uri + name + '.schema.json')!(model);
const serialize = <T>(value: T): T => JSON.parse(JSON.stringify(value));
const resetIds = () => {
  let next = 0;
  (guid as jest.Mock).mockImplementation(() => `remaining-${++next}`);
};
const registeredFactory = async (slug: string) => {
  const call = (registerCreationFunc as jest.Mock).mock.calls.find(
    ([manifest]) => manifest.id === slug,
  );
  if (!call) throw new Error(`No creation callback for ${slug}`);
  return call[1]({ title: 'Logic exercise' });
};
const activity: LabActivity = {
  id: 'lab',
  title: 'Example derivation',
  version: '1',
  keywords: ['logic'],
  spec: {
    type: 'derivation',
    objectives: [{ category: 'proof', required: 'required', mode: 'novice' }],
    maximumScore: 3,
    preview: null,
    opaqueExtension: { future: [null, true] },
  },
};
const factoryModels = async () => {
  resetIds();
  const hotspot = defaultImageHotspotModel();
  const editedHotspot = serialize(hotspot);
  ImageHotspotActions.setImageURL('/media/image.png')(editedHotspot, () => {});
  ImageHotspotActions.setSize(400, 600)(editedHotspot, () => {});
  ImageHotspotActions.setCoords(editedHotspot.choices[0].id, [0, 0, 50, 50])(
    editedHotspot,
    () => {},
  );
  editedHotspot.choices.push(makeHotspot([0, 0, 10, 0, 10, 10]));
  ImageHotspotActions.setMultipleSelection(true)(editedHotspot, () => {});
  const embedded = defaultEmbeddedModel();
  const editedEmbedded = serialize(embedded);
  OliEmbeddedActions.addNewPart()(editedEmbedded, () => {});
  OliEmbeddedActions.editActivityXml('<embed_activity />')(editedEmbedded, () => {});
  OliEmbeddedActions.addResourceURL('/media/image.png')(editedEmbedded, () => {});
  OliEmbeddedActions.setSuppressReviewInteraction(true)(editedEmbedded, () => {});
  OliEmbeddedActions.replaceResourceVerification({
    'image.png': 'verified',
    'missing.png': 'missing',
  })(editedEmbedded, () => {});
  editedEmbedded.bundleStatus = { code: 'ready', message: 'Ready' };
  const lti = await registeredFactory('lti_external_tool');
  const deepLinked = serialize(lti);
  deepLinked.height = 600;
  deepLinked.deepLink = {
    type: 'ltiResourceLink',
    url: '/launch',
    custom: { nested: [null, { any: true }] },
    title: 'Tool',
    text: 'Description',
  };
  const lab = await registeredFactory('oli_logic_lab');
  const selectedLab = serialize(lab);
  selectedLab.activity = activity;
  selectedLab.authoring.source = '<activity />';
  const vlab = defaultVlab();
  const mixed = serialize(vlab);
  VlabActions.setInputType(mixed.inputs[0].id, 'dropdown')(mixed);
  for (const type of ['text', 'numeric', 'math', 'vlabvalue'] as const) {
    const id = `input-${type}`;
    VlabActions.addPart(id)(mixed);
    VlabActions.setInputType(id, type)(mixed);
  }
  VlabActions.setVlabSpecies('input-vlabvalue', 'Na+')(mixed);
  VlabActions.setVlabParameter('input-vlabvalue', 'concentration')(mixed);
  return serialize({
    'image-hotspot': hotspot,
    'image-hotspot-edited': editedHotspot,
    'oli-embedded': embedded,
    'oli-embedded-edited': editedEmbedded,
    'lti-external-tool': lti,
    'lti-external-tool-edited': deepLinked,
    'logic-lab': lab,
    'logic-lab-edited': selectedLab,
    vlab,
    'vlab-edited': mixed,
  });
};

describe('Remaining non-Adaptive activity JSON schemas', () => {
  beforeEach(resetIds);
  it('validates actual creation callbacks, factories, and editor output shared with JSV', async () => {
    const models = await factoryModels();
    expect(models).toEqual(JSON.parse(fs.readFileSync(fixturePath, 'utf8')));
    for (const [key, model] of Object.entries(models))
      expect(valid(key.replace(/-edited$/, ''), model)).toBe(true);
  });
  it('has an exact export schema for every activity manifest', () => {
    for (const directoryName of fs.readdirSync(activitiesDirectory)) {
      const manifestPath = path.join(activitiesDirectory, directoryName, 'manifest.json');
      if (!fs.existsSync(manifestPath)) continue;
      const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
      const exports = fs
        .readdirSync(directory)
        .filter((name) => name.endsWith('-activity.schema.json'))
        .map((name) => JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8')))
        .filter((schema) => schema.allOf?.[1]?.properties?.subType?.const === manifest.id);
      expect(exports).toHaveLength(1);
    }
  });
  it.each(Object.keys(slugs))('enforces strict %s export dispatch', async (name) => {
    const models = await factoryModels();
    const exported: any = {
      id: 'activity',
      type: 'Activity',
      subType: slugs[name],
      title: 'Activity',
      content: models[name as keyof typeof models],
    };
    expect(valid(name + '-activity', exported)).toBe(true);
    exported.subType = 'oli_adaptive';
    expect(valid(name + '-activity', exported)).toBe(false);
    exported.subType = slugs[name];
    exported.typo = true;
    expect(valid(name + '-activity', exported)).toBe(false);
  });
  it.each(['dropdown', 'text', 'numeric', 'math', 'vlabvalue'] as VlabInputType[])(
    'validates all Virtual Lab transitions into %s',
    (type) => {
      for (const previous of [
        'dropdown',
        'text',
        'numeric',
        'math',
        'vlabvalue',
      ] as VlabInputType[]) {
        const model = defaultVlab();
        const id = model.inputs[0].id;
        VlabActions.setInputType(id, previous)(model);
        VlabActions.setInputType(id, type)(model);
        expect(valid('vlab', serialize(model))).toBe(true);
      }
    },
  );
  it('validates hotspot single/multiple selection and typed geometry without shape policy', () => {
    const model = defaultImageHotspotModel();
    for (const multiple of [true, false, true]) {
      ImageHotspotActions.setMultipleSelection(multiple)(model, () => {});
      expect(valid('image-hotspot', model)).toBe(true);
    }
    model.choices[0].coords = [-1.5];
    expect(valid('image-hotspot', model)).toBe(true);
    (model.choices[0] as any).coords = ['1'];
    expect(valid('image-hotspot', model)).toBe(false);
  });
  it('keeps Logic Lab spec extensions and LTI custom values opaque while closing wrappers', async () => {
    const models = await factoryModels();
    const lab = models['logic-lab-edited'];
    expect(valid('logic-lab', lab)).toBe(true);
    lab.activity.typo = true;
    expect(valid('logic-lab', lab)).toBe(false);
    const lti = models['lti-external-tool-edited'];
    lti.deepLink.typo = true;
    expect(valid('lti-external-tool', lti)).toBe(false);
  });
});
