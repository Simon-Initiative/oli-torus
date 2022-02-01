import { Operations } from 'utils/pathOperations';

const ID_PATH = (id: string) => `[?(@.id=='${id}')]`;

type Predicate<T> = (x: T) => boolean;
export interface List<T> {
  getOne: (model: any, id: string) => T;
  getOneBy: (model: any, pred: Predicate<T>) => T;

  getAll: (model: any) => T[];
  getAllBy: (model: any, pred: Predicate<T>) => T[];

  addOne: (x: T) => (model: any) => void;
  removeOne: (id: string) => (model: any) => void;

  setOne: (id: string, x: T) => (model: any) => void;
  setAll: (xs: T[]) => (model: any) => void;
}
export const List: <T>(path: string) => List<T> = (path) => ({
  getOne: (model, id) => Operations.apply(model, Operations.find(path + ID_PATH(id)))[0],
  getOneBy: (model, pred) => Operations.apply(model, Operations.find(path)).filter(pred)[0],

  getAll: (model) => Operations.apply(model, Operations.find(path)),
  getAllBy: (model, pred) => Operations.apply(model, Operations.find(path)).filter(pred),

  addOne(x) {
    return (model: any) => {
      Operations.apply(model, Operations.insert(path, x, -1));
    };
  },

  setOne(id, x) {
    return (model: any) => {
      Operations.apply(model, Operations.replace(path + ID_PATH(id), x));
    };
  },

  setAll(xs) {
    return (model: any) => {
      Operations.apply(model, Operations.replace(path, xs));
    };
  },

  removeOne(id: string) {
    return (model: any) => {
      Operations.apply(model, Operations.filter(path, `[?(@.id!=${id})]`));
    };
  },
});
