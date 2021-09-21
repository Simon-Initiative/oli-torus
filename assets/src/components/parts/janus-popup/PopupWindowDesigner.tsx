import React from 'react';

interface PopupWindowDesignerProps {
  onSave: () => void;
  onCancel: () => void;
}

const PopupWindowDesigner: React.FC<PopupWindowDesignerProps> = (props) => {
  return (
    <div>
      <header>
        <h2>Toolbar</h2>
      </header>
      <section>main edit area...</section>
      <footer>
        <button onClick={props.onSave}>Save</button>
        <button onClick={props.onCancel}>Cancel</button>
      </footer>
    </div>
  );
};

export default PopupWindowDesigner;
