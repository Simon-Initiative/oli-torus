export const CHOICES_PATH = '$..choices';
export const choicePathById = (id: string, path = CHOICES_PATH) => path + `[?(@.id==${id})]`;

export const getChoices = (model: any, path = CHOICES_PATH): Choice[] =>
  Operations.apply(model, Operations.find(path));

export const getChoice = (model: any, id: string, path = CHOICES_PATH): Choice =>
  Operations.apply(model, Operations.find(path + `[?(@.id==${id})]`))[0];
