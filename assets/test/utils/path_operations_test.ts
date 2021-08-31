import { Operations } from 'utils/pathOperations';

const model = () => ({
  authoring: {
    parts: [
      {
        id: 1,
        responses: [{ id: 1 }, { id: 2 }, { id: 3 }],
        hints: [{ id: 1 }, { id: 2 }, { id: 3 }],
      },
      {
        id: 2,
        responses: [{ id: 4 }, { id: 5 }, { id: 6 }],
        hints: [{ id: 4 }, { id: 5 }, { id: 6 }],
      },
    ],
  },
  stem: {
    content: {
      text: 'test',
    },
  },
  choices: [{ id: 1 }, { id: 2 }, { id: 3 }],
});

it('finds items', () => {
  const copy = Object.assign({}, model());

  const op1 = Operations.find('$..choices');
  const op2 = Operations.find('$..responses');
  const op3 = Operations.find('$..choices[?(@.id==1)]');

  const choices = Operations.apply(copy, op1);
  console.log('choices', choices);
  expect(choices).toEqual([{ id: 1 }, { id: 2 }, { id: 3 }]);
  const responses = Operations.apply(copy, op2);
  console.log('responses', responses);
  expect(responses).toEqual([{ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }, { id: 5 }, { id: 6 }]);
  const firstChoice = Operations.apply(copy, op3)[0];
  expect(firstChoice).toEqual({ id: 1 });
});

it('restores choices', () => {
  const copy = Object.assign({}, model());

  const op = Operations.insert('$..choices', { id: 4 }, 0);

  Operations.applyAll(copy, [op]);
  expect(copy.choices.length).toEqual(4);
  expect(copy.choices[0].id).toEqual(4);
});

it('replaces items', () => {
  const copy = Object.assign({}, model());

  const op = Operations.replace('$..choices', [{ id: 4 }]);

  Operations.applyAll(copy, [op]);
  expect(copy.choices.length).toEqual(1);
  expect(copy.choices[0].id).toEqual(4);
});

it('filters items', () => {
  const copy = Object.assign({}, model());

  const op = Operations.filter('$..choices', '[?(@.id!=1)]');

  Operations.applyAll(copy, [op]);
  expect(copy.choices.length).toEqual(2);
  expect(copy.choices[0].id).toEqual(2);
});

it('restores choices robust to size of array', () => {
  const copy = Object.assign({}, model());

  const op = Operations.insert('$..choices', { id: 4 }, 10);

  Operations.applyAll(copy, [op]);
  expect(copy.choices.length).toEqual(4);
  expect(copy.choices[3].id).toEqual(4);
});

it('restores items in parallel arrays', () => {
  const copy = Object.assign({}, model());

  const choices = Operations.insert('$..choices', { id: 4 }, 0);
  const responses = Operations.insert('$.authoring.parts[0].responses', { id: 4 }, 0);

  Operations.applyAll(copy, [choices, responses]);
  expect(copy.choices.length).toEqual(4);
  expect(copy.authoring.parts[0].responses.length).toEqual(4);
});
