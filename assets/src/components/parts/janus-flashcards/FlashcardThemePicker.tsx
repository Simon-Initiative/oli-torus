import React, { CSSProperties, useRef, useState } from 'react';
import { ColorResult, RGBColor, SketchPicker } from 'react-color';
import { FLASHCARD_THEME_PRESETS, isDefaultThemeColor, isPresetThemeColor } from './flashcard-util';

type FlashcardThemePickerProps = {
  value?: string;
  onChange: (color: string | undefined) => void;
  compact?: boolean;
};

const getColorValueString = (value: ColorResult) =>
  `rgba(${value.rgb.r},${value.rgb.g},${value.rgb.b},${value.rgb.a ?? 1})`;

const getRGBColorValue = (value?: string): RGBColor => {
  if (value) {
    const parts = value.replace('rgba(', '').replace(')', '').split(',');
    const [r, g, b, a = '1'] = parts;
    return { r: parseInt(r, 10), g: parseInt(g, 10), b: parseInt(b, 10), a: parseFloat(a) };
  }

  return { r: 255, g: 255, b: 255, a: 1 };
};

const FlashcardThemePicker: React.FC<FlashcardThemePickerProps> = ({
  value,
  onChange,
  compact = false,
}) => {
  const [displayPicker, setDisplayPicker] = useState(false);
  const pickerRef = useRef<HTMLDivElement>(null);
  const color = getRGBColorValue(value);
  const isCustom = !!value && !isPresetThemeColor(value);

  const handleColorBoxClick = () => {
    setDisplayPicker(true);
    document.addEventListener('mousedown', handleClickOutside);
  };

  const handleClickOutside = (event: MouseEvent) => {
    if (pickerRef.current && !pickerRef.current.contains(event.target as Node)) {
      setDisplayPicker(false);
      document.removeEventListener('mousedown', handleClickOutside);
    }
  };

  const customSwatchStyle: CSSProperties = isCustom && value ? { background: value } : {};

  const popupStyle: CSSProperties = {
    position: 'absolute',
    zIndex: 1050,
    right: 0,
    top: 'calc(100% + 8px)',
  };

  return (
    <div className={`fc-theme-picker${compact ? ' is-compact' : ''}`}>
      <span className="fc-theme-picker-label">Theme</span>
      <div className="fc-theme-picker-swatches">
        <button
          type="button"
          className={`fc-theme-swatch fc-theme-swatch-default${
            isDefaultThemeColor(value) ? ' is-selected' : ''
          }`}
          aria-label="Default theme (white)"
          aria-pressed={isDefaultThemeColor(value)}
          onClick={() => onChange(undefined)}
        />

        {FLASHCARD_THEME_PRESETS.map((preset) => {
          const isSelected = value === preset.color;

          return (
            <button
              key={preset.id}
              type="button"
              className={`fc-theme-swatch${isSelected ? ' is-selected' : ''}`}
              style={{ background: preset.color }}
              aria-label={`Theme color ${preset.id}`}
              aria-pressed={isSelected}
              onClick={() => onChange(preset.color)}
            />
          );
        })}

        <div className="fc-theme-custom-wrap">
          <button
            type="button"
            className={`fc-theme-swatch fc-theme-swatch-custom${isCustom ? ' is-selected' : ''}`}
            style={customSwatchStyle}
            aria-label="Custom color"
            aria-pressed={isCustom}
            onClick={handleColorBoxClick}
          >
            <span className="fc-theme-swatch-custom-label">Custom</span>
          </button>

          {displayPicker ? (
            <div style={popupStyle} className="color-picker-widget" ref={pickerRef}>
              <SketchPicker
                color={color}
                onChangeComplete={(nextColor) => onChange(getColorValueString(nextColor))}
              />
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
};

export default FlashcardThemePicker;
