import React, { CSSProperties, useEffect, useRef, useState } from 'react';
import { SketchPicker } from 'react-color';
interface ColorPickerProps {
  value: any;
}

const getColorValueString = (value: any) => {
  return (
    value.rgb.a && value.rgb.a != 0 ?
      `rgba(${value.rgb.r},${value.rgb.g},${value.rgb.b},${value.rgb.a})`
      :
      `rgb(${value.rgb.r},${value.rgb.g},${value.rgb.b})`
  );
}

const getRGBColorValue = (value: any) => {
  if (value) {
    const parts = value.replace('rgba(', '').replace('rgb(','').replace(')', '').split(',');
    return { r: parts[0], g: parts[1], b: parts[2], a: parts.length > 3 ? parts[3] : 100 }
  }
  return { r: 255, g: 255, b: 255, a: 0 };
}

const ColorPickerWidget: React.FC<ColorPickerProps> = (props: any) => {
  const color = getRGBColorValue(props.value);
  const [displayPicker, setDisplayPicker] = useState(false);

  const handleColorBoxClick = () => {
    setDisplayPicker(true);
    document.addEventListener("mousedown", handleClick);
  };
  const handleClick = (event: any) => {
    if (pickerRef.current && !pickerRef.current.contains(event.target)) {
      setDisplayPicker(false);
      document.removeEventListener("mousedown", handleClick);
    }
  }
  const pickerRef = useRef<HTMLDivElement>(null);
  const colorDiv: CSSProperties = {
    width: '36px',
    height: '14px',
    borderRadius: '2px',
    border: '1px solid black',
    background: `rgba(${color.r}, ${color.g}, ${color.b}, ${color.a})`,
  }
  const popup: CSSProperties = {
    position: 'absolute',
    zIndex: 2,
    left: 0,
    top: '25px'
  }
  return (
    <div className="d-flex justify-content-between" >
      <span className="form-label">{props.label}</span>
      <div>
        <div style={colorDiv} onClick={handleColorBoxClick}></div>
        {displayPicker ?
          <div style={popup} ref={pickerRef}>
            <SketchPicker
              color={color}
              onChangeComplete={color => {
                props.onChange(getColorValueString(color));
              }}
            /></div>
          : null
        }
      </div>
    </div>
  );
};

export default ColorPickerWidget;
