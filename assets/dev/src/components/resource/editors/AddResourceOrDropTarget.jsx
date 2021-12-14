import { AddActivity } from 'components/content/add_resource_content/AddActivity';
import { AddContent } from 'components/content/add_resource_content/AddContent';
import { AddOther } from 'components/content/add_resource_content/AddOther';
import { AddResourceContent } from 'components/content/add_resource_content/AddResourceContent';
import React from 'react';
import { DropTarget } from './dragndrop/DropTarget';
export const AddResourceOrDropTarget = (props) => {
    if (props.isReorderMode) {
        return <DropTarget {...props} isLast={props.id === 'last'}/>;
    }
    return (<AddResourceContent {...props} isLast={props.id === 'last'}>
      <AddContent {...props}/>
      <AddActivity {...props}/>
      <AddOther {...props}/>
    </AddResourceContent>);
};
//# sourceMappingURL=AddResourceOrDropTarget.jsx.map