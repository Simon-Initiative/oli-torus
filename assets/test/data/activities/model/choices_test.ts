import { Choices } from 'data/activities/model/choices';

describe('choices test', () => {
  const model = {
    stem: { content: { model: [{ type: 'p', children: [{ text: 'test' }] }] } },
    choices: [
      { id: 'yes', content: { model: [{ type: 'p', children: [{ text: 'test' }] }] } },
      { id: 'no', content: { model: [{ type: 'p', children: [{ text: 'test' }] }] } },
    ],
  };

  it('finds one', () => {
    expect(Choices.getOne(model, 'no')).toEqual(model.choices[1]);
  });
});
