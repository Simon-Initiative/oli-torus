import { DragHandle } from '../DragHandle';
import { EditLink } from '../../misc/EditLink';
import { ObjectivesList } from './ObjectivesList';
import { Purpose } from 'components/content/Purpose';
import { DeleteButton } from 'components/misc/DeleteButton';
import { Purpose as PurposeType, ResourceContent, ActivityReference } from 'data/content/resource';
import * as Immutable from 'immutable';

interface ActivityBlockProps {
  children?: JSX.Element | JSX.Element[];
  editMode: boolean;
  content: Immutable.List<ResourceContent>;
  purposes: PurposeType[];
  contentItem: ActivityReference;
  label: string;
  projectSlug: string;
  resourceSlug: string;
  objectives: string[];
  onDragStart: (e: React.DragEvent<HTMLDivElement>, id: string) => void;
  onDragEnd: () => void;
  onEditPurpose: (purpose: string) => void;
  onRemove: () => void;
}
export const ActivityBlock = (props: ActivityBlockProps) => {
  const id = `activity-header${props.contentItem.activitySlug}`;
  return (
    <div className="resource-content-frame card">
      <div className="card-header px-2"
        draggable={true}
        onDragStart={e => props.onDragStart(e, id)}
        onDragEnd={props.onDragEnd}>
        <div className="d-flex flex-row align-items-center">

          <div className="d-flex align-items-center flex-grow-1">
            <DragHandle style={{ height: 24, marginRight: 10 }} />
            <Purpose
              purpose={props.contentItem.purpose}
              purposes={props.purposes}
              editMode={props.editMode}
              onEdit={props.onEditPurpose} />
            <EditLink
              label={props.label}
              href={`/project/${props.projectSlug}/resource/${props.resourceSlug}/activity/${props.contentItem.activitySlug}`} />
          </div>

          <DeleteButton editMode={props.content.size > 1} onClick={props.onRemove} />
        </div>
      </div>

      <ObjectivesList objectives={props.objectives} ></ObjectivesList>

      <div className="card-body">

        {props.children}

      </div>
    </div>
  );
};
