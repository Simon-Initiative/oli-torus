import { applyOperations, InsertOperation } from 'utils/undo';

const model = () =>  ({
  authoring: {
    parts: [
      {
        id: 1,
        responses: [{ id: 1}, { id: 2}, { id: 3}],
        hints: [{ id: 1}, { id: 2}, { id: 3}],
      }

    ]
  },
  stem: {
    content: {
      text: 'test'
    }
  },
  choices: [{ id: 1}, { id: 2}, { id: 3}]
});

it('restores choices', () => {
  const copy = Object.assign({}, model());

  const op : InsertOperation = {
    item: { id: 4},
    index: 0,
    path: '$.choices'
  };

  applyOperations(copy, [op]);
  expect(copy.choices.length).toEqual(4);
  expect(copy.choices[0].id).toEqual(4);

});


it('restores choices robust to size of array', () => {
  const copy = Object.assign({}, model());

  const op : InsertOperation = {
    item: { id: 4},
    index: 10,
    path: '$.choices'
  };

  applyOperations(copy, [op]);
  expect(copy.choices.length).toEqual(4);
  expect(copy.choices[3].id).toEqual(4);

});


it('restores items in parallel arrays', () => {
  const copy = Object.assign({}, model());

  const choices : InsertOperation = {
    item: { id: 4},
    index: 0,
    path: '$.choices'
  };
  const responses : InsertOperation = {
    item: { id: 4},
    index: 0,
    path: '$.authoring.parts[0].responses'
  };

  applyOperations(copy, [choices, responses]);
  expect(copy.choices.length).toEqual(4);
  expect(copy.authoring.parts[0].responses.length).toEqual(4);

});
