import React, { useRef, useState } from 'react';
import { SketchPicker } from 'react-color';
const getColorValueString = (value) => {
    return `rgba(${value.rgb.r},${value.rgb.g},${value.rgb.b},${value.rgb.a})`;
};
const getRGBColorValue = (value) => {
    if (value) {
        const parts = value.replace('rgba(', '').replace(')', '').split(',');
        const [r, g, b, a = '100'] = parts;
        return { r: parseInt(r, 10), g: parseInt(g, 10), b: parseInt(b, 10), a: parseFloat(a) };
    }
    return { r: 255, g: 255, b: 255, a: 100 };
};
const ColorPickerWidget = (props) => {
    const color = getRGBColorValue(props.value);
    const [displayPicker, setDisplayPicker] = useState(false);
    const handleColorBoxClick = () => {
        setDisplayPicker(true);
        document.addEventListener('mousedown', handleClick);
    };
    const handleClick = (event) => {
        if (pickerRef.current && !pickerRef.current.contains(event.target)) {
            setDisplayPicker(false);
            document.removeEventListener('mousedown', handleClick);
        }
    };
    const pickerRef = useRef(null);
    const colorDiv = {
        width: '36px',
        height: '14px',
        borderRadius: '2px',
        border: '1px solid black',
        background: `rgba(${color.r}, ${color.g}, ${color.b}, ${color.a})`,
    };
    const popup = {
        position: 'absolute',
        zIndex: 2,
        left: 0,
        top: '25px',
    };
    return (<div className="d-flex justify-content-between">
      <span className="form-label">{props.label}</span>
      <div>
        <div style={colorDiv} onClick={handleColorBoxClick}></div>
        {displayPicker ? (<div style={popup} ref={pickerRef}>
            <SketchPicker color={color} onChangeComplete={(color) => {
                props.onChange(getColorValueString(color));
                props.onBlur(props.id, getColorValueString(color));
            }}/>
          </div>) : null}
      </div>
    </div>);
};
export default ColorPickerWidget;
//# sourceMappingURL=ColorPickerWidget.jsx.map