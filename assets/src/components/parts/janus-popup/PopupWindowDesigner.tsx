import PartsLayoutRenderer from 'components/activities/adaptive/components/delivery/PartsLayoutRenderer';
import React from 'react';

interface PopupWindowDesignerProps {
  parts?: any[];
  onSave: () => void;
  onCancel: () => void;
}

const PopupWindowDesigner: React.FC<PopupWindowDesignerProps> = (props) => {
  const [parts, setParts] = React.useState<any[]>(props.parts || []);

  console.log('PD PARTS', parts);

  return (
    <div className="popup-window-designer">
      <style>
        {`
          .popup-window-designer {
            width: 100%;
            height: 100%;
            background-color: ivory !important;
            top: 0 !important;
            left: 0 !important;
          }

          .popup-designer-toolbar {
            height: 5%;
            width: 100%;
          }

          .popup-designer-canvas {
            contain: layout;
            height: 95%;
            width: 100%;
            background-color: #eee;
          }
        `}
      </style>
      <header className="popup-designer-toolbar">
        <button className="px-2 btn btn-link">Text</button>
        <button className="px-2 btn btn-link">Image</button>
        <button className="px-2 btn btn-link">Audio</button>
        <button className="px-2 btn btn-link">Video</button>
        <button className="px-2 btn btn-link">Iframe</button>
        <button className="px-2 btn btn-link" onClick={props.onSave}>
          Save
        </button>
        <button className="px-2 btn btn-link" onClick={props.onCancel}>
          Cancel
        </button>
      </header>
      <section className="popup-designer-canvas">
        <PartsLayoutRenderer parts={parts} />
      </section>
    </div>
  );
};

export default PopupWindowDesigner;
