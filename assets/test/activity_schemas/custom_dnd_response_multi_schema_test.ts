import Ajv from 'ajv';
import fs from 'fs';
import path from 'path';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import { CustomDnDActions } from 'components/activities/custom_dnd/actions';
import { defaultModel as defaultDnD } from 'components/activities/custom_dnd/utils';
import { MultiInputType } from 'components/activities/multi_input/schema';
import { ResponseMultiInputActions } from 'components/activities/response_multi/actions';
import { defaultModel as defaultResponseMulti } from 'components/activities/response_multi/utils';
import { makeFeedback } from 'components/activities/types';
import { ItemConfigs } from 'data/activities/model/match';
import guid from 'utils/guid';

jest.mock('utils/guid', () => ({ __esModule: true, default: jest.fn() }));
const uri = 'http://torus.oli.cmu.edu/schemas/v0-1-0/';
const directory = path.resolve(__dirname, '../../../priv/schemas/v0-1-0');
const fixturePath = path.resolve(
  __dirname,
  '../../../test/support/fixtures/custom_dnd_response_multi_models.json',
);
const ajv = new Ajv({ strict: false, allErrors: true, logger: false });
for (const name of fs.readdirSync(directory).filter((name) => name.endsWith('.json'))) {
  ajv.addSchema(JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8')));
}
const valid = (name: string, model: unknown) => ajv.getSchema(uri + name + '.schema.json')!(model);
const serialize = <T>(value: T): T => JSON.parse(JSON.stringify(value));
const resetIds = () => {
  let next = 0;
  (guid as jest.Mock).mockImplementation(() => `dnd-response-multi-${++next}`);
};
const factoryModels = () => {
  resetIds();
  const dnd = defaultDnD();
  dnd.authoring.parts[0].explanation = makeFeedback('Explanation');
  const editedDnD = serialize(dnd);
  CustomDnDActions.editLayoutStyles('.target { width: 100%; }')(editedDnD);
  CustomDnDActions.editTargetArea('<div class="target" input_ref="area"></div>')(editedDnD);
  CustomDnDActions.editInitiators('<div class="initiator" input_val="drag">Drag me</div>')(
    editedDnD,
  );
  CustomDnDActions.editPart('input1', 'renamed')(editedDnD);
  CustomDnDActions.removePart('input3')(editedDnD);
  StemActions.editStemAndPreviewText([{ type: 'p', children: [{ text: 'Drag the labels.' }] }])(
    editedDnD,
  );
  const responseMulti = defaultResponseMulti();
  responseMulti.authoring.parts[0].explanation = makeFeedback('Explanation');
  const mixed = serialize(responseMulti);
  ResponseMultiInputActions.setInputType(mixed.inputs[0].id, 'dropdown')(mixed);
  for (const type of ['text', 'numeric', 'math', 'math_expression'] as const) {
    const id = `input-${type}`;
    ResponseMultiInputActions.addPart(id)(mixed);
    ResponseMultiInputActions.setInputType(id, type)(mixed);
  }
  const grouped = serialize(mixed);
  ResponseMultiInputActions.moveInputToPart('input-text', grouped.inputs[0].partId)(
    grouped,
    () => {},
  );
  return serialize({
    'custom-dnd': dnd,
    'custom-dnd-edited': editedDnD,
    'response-multi': responseMulti,
    'response-multi-mixed': mixed,
    'response-multi-grouped': grouped,
  });
};
const inputTypes: MultiInputType[] = ['dropdown', 'text', 'numeric', 'math', 'math_expression'];

describe('Custom DND and Response Multi JSON schemas', () => {
  beforeEach(resetIds);
  it('validates actual factories and editor/grouping actions shared with JSV fixtures', () => {
    const models = factoryModels();
    expect(models).toEqual(JSON.parse(fs.readFileSync(fixturePath, 'utf8')));
    for (const [name, model] of Object.entries(models)) {
      expect(valid(name.startsWith('custom-dnd') ? 'custom-dnd' : 'response-multi', model)).toBe(
        true,
      );
    }
  });
  it('validates add, rename and remove Custom DND parts', () => {
    const random = jest.spyOn(Math, 'random').mockReturnValue(0.125);
    try {
      const model = defaultDnD();
      CustomDnDActions.addPart()(model);
      expect(valid('custom-dnd', model)).toBe(true);
      CustomDnDActions.editPart('part_125', 'new-part')(model);
      CustomDnDActions.removePart('new-part')(model);
      expect(valid('custom-dnd', model)).toBe(true);
    } finally {
      random.mockRestore();
    }
  });
  it.each(inputTypes)('validates Response Multi transitions into %s', (type) => {
    for (const previous of inputTypes) {
      const model = defaultResponseMulti();
      const id = model.inputs[0].id;
      ResponseMultiInputActions.setInputType(id, previous)(model);
      ResponseMultiInputActions.setInputType(id, type)(model);
      expect(valid('response-multi', serialize(model))).toBe(true);
    }
  });
  it('shares the same declared math item settings as Multi Input', () => {
    const model = defaultResponseMulti() as any;
    model.inputs[0].inputType = 'math_expression';
    model.inputs[0].itemConfig = ItemConfigs.mathExpression('algebraic', {});
    const response = model.authoring.parts[0].responses[0];
    delete response.rule;
    response.matchConfig = {
      version: 1,
      type: 'math_expression',
      math: { future: [null, { arbitrary: true }], $ref: 'data-only' },
    };
    expect(valid('response-multi', model)).toBe(true);
    model.inputs[0].itemConfig.typo = true;
    expect(valid('response-multi', model)).toBe(false);
    delete model.inputs[0].itemConfig.typo;
    response.matchConfig.typo = true;
    expect(valid('response-multi', model)).toBe(false);
  });
  it('validates Response Multi contributed responses separately from Multi Input', () => {
    const model = defaultResponseMulti() as any;
    model.authoring.responses = [{ user_name: 'Learner', text: 'Answer' }];
    expect(valid('response-multi', model)).toBe(true);
    model.authoring.responses[0].users = ['Learner'];
    expect(valid('response-multi', model)).toBe(false);
    delete model.authoring.responses[0].users;
    delete model.authoring.responses[0].user_name;
    expect(valid('response-multi', model)).toBe(false);
  });
  it('keeps DND dimensions, HTML and CSS as strings', () => {
    const model = defaultDnD() as any;
    model.height = '100%';
    model.width = 'auto';
    model.layoutStyles = 'unparsed CSS {';
    model.targetArea = 'unparsed HTML <';
    expect(valid('custom-dnd', model)).toBe(true);
    model.height = 400;
    expect(valid('custom-dnd', model)).toBe(false);
  });
  it.each(['custom-dnd', 'response-multi'])('validates strict %s export dispatch', (name) => {
    const exported: any = {
      id: 'activity',
      type: 'Activity',
      subType: name === 'custom-dnd' ? 'oli_custom_dnd' : 'oli_response_multi',
      title: 'Question',
      content: name === 'custom-dnd' ? defaultDnD() : defaultResponseMulti(),
    };
    expect(valid(name + '-activity', exported)).toBe(true);
    exported.subType = 'oli_multi_input';
    expect(valid(name + '-activity', exported)).toBe(false);
    exported.subType = name === 'custom-dnd' ? 'oli_custom_dnd' : 'oli_response_multi';
    exported.content.authoring.typo = true;
    expect(valid(name + '-activity', exported)).toBe(false);
  });
});
