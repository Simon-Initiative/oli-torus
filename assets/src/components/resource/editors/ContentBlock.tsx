import { DragHandle } from '../DragHandle';
import { DeleteButton } from 'components/misc/DeleteButton';
import { getContentDescription } from 'data/content/utils';
import { Purpose as PurposeType, ResourceContent, StructuredContent } from 'data/content/resource';
import * as Immutable from 'immutable';
import { Purpose } from 'components/content/Purpose';
import { useEditor } from 'slate-react';

const getDescription = (item: ResourceContent) => {
  return item.type === 'content'
    ? getContentDescription(item)
    : '';
};

interface ContentBlockProps {
  editMode: boolean;
  children?: JSX.Element | JSX.Element[] ;
  content: Immutable.List<ResourceContent>;
  purposes: PurposeType[];
  contentItem: StructuredContent;
  index: number;
  onDragStart: (e: React.DragEvent<HTMLDivElement>, id: string) => void;
  onDragEnd: () => void;
  onEditPurpose: (purpose: string) => void;
  onRemove: () => void;
}
export const ContentBlock = (props: ContentBlockProps) => {
  const id = `content-header-${props.index}`;
  return (
    <div className="resource-content-frame card"
      draggable={true}
      onDragStart={e => props.onDragStart(e, id)}
      onDragEnd={props.onDragEnd}>
      <div id={id} className="card-header px-2">
        <div className="d-flex flex-row align-items-center">
          <div className="d-flex align-items-center flex-grow-1">
            <DragHandle style={{ height: 24, marginRight: 10 }} />
            <Purpose
              purpose={props.contentItem.purpose}
              purposes={props.purposes}
              editMode={props.editMode}
              onEdit={props.onEditPurpose} />
          </div>
          <DeleteButton
            editMode={props.content.size > 1}
            onClick={props.onRemove} />
        </div>
        <div className="description text-secondary ellipsize-overflow flex-1 mx-4 mt-2">
          {getDescription(props.contentItem)}
        </div>
      </div>
      <div className="card-body">
        <div draggable={true} onDragStart={(e) => { e.preventDefault(); e.stopPropagation(); }}>

          {props.children}

        </div>
      </div>
    </div>
  );
};
