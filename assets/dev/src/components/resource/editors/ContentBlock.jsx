import * as React from 'react';
import { DragHandle } from '../DragHandle';
import { DeleteButton } from 'components/misc/DeleteButton';
import { getContentDescription } from 'data/content/utils';
import { Purpose } from 'components/content/Purpose';
import { classNames } from 'utils/classNames';
const getDescription = (item) => {
    return item.type === 'content' ? getContentDescription(item) : '';
};
const maybeRenderDeliveryPurposeContainer = (props) => {
    var _a;
    const purposeLabel = (_a = props.purposes.find((p) => p.value === props.contentItem.purpose)) === null || _a === void 0 ? void 0 : _a.label;
    if (props.contentItem.purpose === 'none') {
        return props.children;
    }
    return (<div className="content-block-structured-content">
      <div className={`content-purpose ${props.contentItem.purpose}`}>
        <div className="content-purpose-label">{purposeLabel}</div>
        <div className="content-purpose-content">{props.children}</div>
      </div>
    </div>);
};
export const ContentBlock = (props) => {
    const id = `content-header-${props.index}`;
    return (<div className={classNames([
            'content-block',
            'resource-content-frame',
            'card',
            `purpose-${props.contentItem.purpose}`,
        ])} draggable={props.editMode} onDragStart={(e) => props.onDragStart(e, id)} onDragEnd={props.onDragEnd}>
      <div id={id} className="card-header px-2">
        <div className="d-flex flex-row align-items-center">
          <div className="d-flex align-items-center flex-grow-1">
            <DragHandle style={{ height: 24, marginRight: 10 }}/>
          </div>

          <Purpose purpose={props.contentItem.purpose} purposes={props.purposes} editMode={props.editMode} onEdit={props.onEditPurpose}/>

          <DeleteButton editMode={props.content.size > 1} onClick={props.onRemove}/>
        </div>
      </div>
      <div className="card-body delivery">
        <div className="content" draggable={props.editMode} onDragStart={(e) => {
            e.preventDefault();
            e.stopPropagation();
        }}>
          {maybeRenderDeliveryPurposeContainer(props)}
        </div>
      </div>
      <div className="reorder-mode-description">{getDescription(props.contentItem)}</div>
    </div>);
};
//# sourceMappingURL=ContentBlock.jsx.map