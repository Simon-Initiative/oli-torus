import { IPartLayout } from '../../../delivery/store/features/activities/slice';

export interface Template {
  name: string;
  templateType: string;
  parts: {
    id: string;
    inherited: boolean;
    owner: string;
    type: string;
  }[];
  partsLayout: IPartLayout[];
}
