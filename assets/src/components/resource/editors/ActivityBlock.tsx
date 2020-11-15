import { DragHandle } from '../DragHandle';
import { EditLink } from '../../misc/EditLink';
import { Purpose } from 'components/content/Purpose';
import { DeleteButton } from 'components/misc/DeleteButton';
import { Purpose as PurposeType, ResourceContent, ActivityReference } from 'data/content/resource';
import * as Immutable from 'immutable';

interface ActivityCardProps {
  onDragStart: (e: React.DragEvent<HTMLDivElement>, id: string) => void;
  onDragEnd: () => void;
  editMode: boolean;
  editor: JSX.Element;
  onEditPurpose: (purpose: string) => void;
  content: Immutable.List<ResourceContent>;
  onRemove: () => void;
  purposes: PurposeType[];
  contentItem: ActivityReference;

  label: string;
  projectSlug: string;
  resourceSlug: string;
}
export const ActivityCard = (props: ActivityCardProps) => {
  const id = `activity-header${props.contentItem.activitySlug}`;
  return (
    <div className="resource-content-frame card">
      <div className="card-header pl-2"
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
        {props.editor}
      </div>
    </div>
  );
};
