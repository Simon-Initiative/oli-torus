import { ResourceId } from 'data/types';
export { ResourceId } from 'data/types';

export type Objective = {
  id: ResourceId;
  title: string;
  parentId: ResourceId | null;
};
