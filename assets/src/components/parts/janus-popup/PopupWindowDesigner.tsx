import LayoutEditor from 'components/activities/adaptive/components/authoring/LayoutEditor';
import React, { useCallback } from 'react';
import guid from 'utils/guid';
import { AnyPartComponent } from '../types/parts';

interface PopupWindowDesignerProps {
  config: any;
  parts?: any[];
  onSave: (parts: AnyPartComponent[]) => void;
  onCancel: () => void;
}

const PopupWindowDesigner: React.FC<PopupWindowDesignerProps> = (props) => {
  const canvasRef = React.useRef(null);
  const [parts, setParts] = React.useState<any[]>(props.parts || []);

  const handleChange = (parts: AnyPartComponent[]) => {
    console.log('popup designer layout change', parts);
    setParts(parts);
  };

  const handleSelect = (partId: string) => {
    console.log('popup designer select', partId);
  };

  const handleSave = useCallback(() => {
    console.log('popup designer save', parts);
    props.onSave(parts);
  }, [parts]);

  const handleAddPart = useCallback(
    (type: string) => {
      console.log('popup designer add component', type);
      // TODO: involve the part registry instead
      const PartClass = customElements.get(type);
      if (!PartClass) {
        console.error(`Unknown part type: ${type}`);
        return;
      }
      const part = new PartClass() as any;
      const newPartData = {
        id: `${type}-${guid()}`,
        type, // TODO: use part registry instead
        custom: {
          x: 10,
          y: 10,
          z: 0,
          width: 100,
          height: 100,
        },
      };
      const creationContext = { transform: { ...newPartData.custom } };
      if (part.createSchema) {
        newPartData.custom = { ...newPartData.custom, ...part.createSchema(creationContext) };
      }
      setParts([...parts, newPartData]);
    },
    [parts],
  );

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
        <button className="px-2 btn btn-link" onClick={() => handleAddPart('janus-text-flow')}>
          Text
        </button>
        <button className="px-2 btn btn-link" onClick={() => handleAddPart('janus-image')}>
          Image
        </button>
        <button className="px-2 btn btn-link" onClick={() => handleAddPart('janus-audio')}>
          Audio
        </button>
        <button className="px-2 btn btn-link" onClick={() => handleAddPart('janus-video')}>
          Video
        </button>
        <button className="px-2 btn btn-link" onClick={() => handleAddPart('janus-capi-iframe')}>
          Iframe
        </button>
        <button className="px-2 btn btn-link" onClick={handleSave}>
          Save
        </button>
        <button className="px-2 btn btn-link" onClick={props.onCancel}>
          Cancel
        </button>
      </header>
      <section ref={canvasRef} className="popup-designer-canvas">
        <LayoutEditor
          id="popup-designer-1"
          width={props.config.width}
          height={props.config.height}
          backgroundColor={'lightblue'}
          parts={parts}
          selected={''}
          onChange={handleChange}
          onSelect={handleSelect}
        />
      </section>
    </div>
  );
};

export default PopupWindowDesigner;
