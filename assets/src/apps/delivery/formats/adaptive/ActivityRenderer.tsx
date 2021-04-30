import PartComponent from '../../components/PartComponent';
import React from 'react';

// NOTE: this should not be rendering the parts directly eventually
// it should render any activity? not just adaptive?
// the adaptive-activity web component should render
// the parts
const ActivityRenderer: React.FC<any> = (props: any) => {
  // console.log('AR', { props });
  return (
    <div>
      {props.parts.map((partDefinition: any) => {
        const partProps = {
          id: partDefinition.id,
          type: partDefinition.type,
          model: partDefinition.custom,
          state: [],
          onInit: async () => true,
          onReady: async () => true,
        };
        return <PartComponent key={partDefinition.id} {...partProps} />;
      })}
    </div>
  );
};

export default ActivityRenderer;
