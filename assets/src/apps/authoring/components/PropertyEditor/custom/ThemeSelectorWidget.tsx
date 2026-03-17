import React from 'react';
import { Form } from 'react-bootstrap';

const DEFAULT_THEME_URL = '/css/delivery_adaptive_themes_default_light.css';
/** Sentinel for "Custom Theme" so theme is never empty (keeps customCssUrl field visible in form). */
export const CUSTOM_THEME_DEFAULT = '__custom_theme__';

interface ThemeSelectorWidgetProps {
  id: string;
  value: string;
  onChange: (value: string) => void;
  onBlur?: (id: string, value: string) => void;
  onFocus?: () => void;
}

/**
 * Theme selector for Advanced Author: dropdown with "Default Theme" and "Custom Theme".
 * Uses a sentinel value for Custom so the theme field is never empty (keeps sibling customCssUrl visible).
 */
const ThemeSelectorWidget: React.FC<ThemeSelectorWidgetProps> = ({
  id,
  value,
  onChange,
  onBlur,
  onFocus,
}) => {
  // Only treat explicit default URL as default; empty/undefined/sentinel = custom (so textbox stays visible)
  const isDefault = value === DEFAULT_THEME_URL;

  const handleChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const isDefaultSelected = e.target.value === 'default';
    const next = isDefaultSelected ? DEFAULT_THEME_URL : CUSTOM_THEME_DEFAULT;
    onChange(next);
  };

  const handleCustomUrlChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const customUrl = e.target.value;
    onChange(customUrl || CUSTOM_THEME_DEFAULT);
  };

  const showCustomUrlInput = !isDefault;
  const customUrlValue = showCustomUrlInput && value !== CUSTOM_THEME_DEFAULT ? value : '';

  return (
    <Form.Group style={{ marginTop: '8px' }}>
      <Form.Label htmlFor={`${id}-custom-url`}>Theme</Form.Label>
      <Form.Control
        as="select"
        id={id}
        value={isDefault ? 'default' : 'custom'}
        onChange={handleChange}
        onFocus={onFocus}
        style={{ marginBottom: '13px' }}
      >
        <option value="default">Default Theme</option>
        <option value="custom">Custom Theme</option>
      </Form.Control>
      {showCustomUrlInput && (
        <>
          <Form.Label htmlFor={`${id}-custom-url`} style={{ marginTop: '8px' }}>
            Custom Theme URL
          </Form.Label>
          <Form.Control
            type="text"
            id={`${id}-custom-url`}
            value={customUrlValue}
            onChange={handleCustomUrlChange}
            onFocus={onFocus}
            placeholder="Enter custom theme URL"
          />
        </>
      )}
    </Form.Group>
  );
};

export default ThemeSelectorWidget;
