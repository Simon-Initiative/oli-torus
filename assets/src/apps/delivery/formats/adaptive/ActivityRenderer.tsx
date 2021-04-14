import Image, { tagName as ImageTag } from "components/parts/janus-image/Image";
import TextFlow, {
  tagName as TextFlowTag,
} from "components/parts/janus-text-flow/TextFlow";
import React from "react";

const builtInPartTypes: any = {
  [TextFlowTag]: TextFlow,
  [ImageTag]: Image,
};

// NOTE: this should not be rendering the parts directly eventually
// it should render any activity? not just adaptive? the adaptive-activity web component should render
// the parts
const ActivityRenderer: React.FC<any> = (props) => {
  console.log("AR", { props });
  return (
    <div>
      {props.parts.map((partDefinition: any) => {
        const PartComponent = builtInPartTypes[partDefinition.type];
        const partProps = {
          model: partDefinition.custom,
          state: [],
          onReady: () => true,
        };
        return <PartComponent key={partDefinition.id} {...partProps} />;
      })}
    </div>
  );
};

export default ActivityRenderer;
