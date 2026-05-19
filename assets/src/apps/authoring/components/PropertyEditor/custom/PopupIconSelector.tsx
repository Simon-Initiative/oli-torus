import React, { Fragment, useMemo } from 'react';
import { Dropdown } from 'react-bootstrap';

interface PopupIconSelectorProps {
  id: string;
  label: string;
  value: string;
  onChange: (value: string) => void;
  onBlur: (id: string, value: string) => void;
}

// Icon mapping structure
const iconOptions = {
  none: { url: '', label: 'None' },
  question_mark: {
    label: 'Question mark',
    icon: '﹖',
    colors: {
      orange: { url: '/repo/icons/question_mark_orange_32x32.png', label: 'Orange' },
      red: { url: '/repo/icons/question_mark_red_32x32.png', label: 'Red' },
      green: { url: '/repo/icons/question_mark_green_32x32.png', label: 'Green' },
      blue: { url: '/repo/icons/question_mark_blue_32x32.png', label: 'Blue' },
    },
  },
  information: {
    label: 'Information',
    icon: 'ℹ',
    colors: {
      orange: { url: '/repo/icons/information_mark_orange_32x32.png', label: 'Orange' },
      red: { url: '/repo/icons/information_mark_red_32x32.png', label: 'Red' },
      green: { url: '/repo/icons/information_mark_green_32x32.png', label: 'Green' },
      blue: { url: '/repo/icons/information_mark_blue_32x32.png', label: 'Blue' },
    },
  },
  exclamation: {
    label: 'Exclamation',
    icon: '﹗',
    colors: {
      orange: { url: '/repo/icons/exclamation_mark_orange_32x32.png', label: 'Orange' },
      red: { url: '/repo/icons/exclamation_mark_red_32x32.png', label: 'Red' },
      green: { url: '/repo/icons/exclamation_mark_green_32x32.png', label: 'Green' },
      blue: { url: '/repo/icons/exclamation_mark_blue_32x32.png', label: 'Blue' },
    },
  },
};

// Create a reverse mapping from URL to display label
const urlToLabelMap: Record<string, string> = {};
Object.entries(iconOptions).forEach(([categoryKey, category]) => {
  if (categoryKey === 'none') {
    urlToLabelMap[''] = 'None';
  } else if ('colors' in category) {
    Object.entries(category.colors).forEach(([colorKey, colorOption]) => {
      if (
        colorOption &&
        typeof colorOption === 'object' &&
        'url' in colorOption &&
        'label' in colorOption
      ) {
        urlToLabelMap[colorOption.url] = `${category.label} - ${colorOption.label}`;
      }
    });
  }
});

export const PopupIconSelector: React.FC<PopupIconSelectorProps> = ({
  id,
  label,
  value,
  onChange,
  onBlur,
}) => {
  // Get the display label for the current value
  const displayLabel = useMemo(() => {
    const currentValue = value || '';
    if (currentValue === '') {
      return 'None';
    }
    return urlToLabelMap[currentValue] || currentValue;
  }, [value]);

  const handleSelect = (url: string) => {
    onChange(url);
    if (onBlur) {
      setTimeout(() => onBlur(id, url), 0);
    }
  };

  return (
    <Fragment>
      <style>{`
        .popup-icon-selector-toggle {
          background-color: white !important;
          color: black !important;
        }
        .dark .popup-icon-selector-toggle {
          background-color: #2a2b2e !important;
          color: #f5f5f5 !important;
        }
      `}</style>
      <div className="d-flex flex-column">
        {label && <span className="form-label">{label}</span>}
        <Dropdown>
          <Dropdown.Toggle
            variant="link"
            id={id}
            className="form-control dropdown-toggle d-flex justify-content-between align-items-center popup-icon-selector-toggle"
            style={{
              textAlign: 'left',
              height: '37px',
            }}
          >
            <span>{displayLabel}</span>
            <i
              className="fas fa-caret-down my-auto ml-auto"
              style={{ float: 'right', paddingRight: '10px' }}
            />
          </Dropdown.Toggle>

          <Dropdown.Menu
            className="popup-icon-selector-menu"
            style={{ maxHeight: '300px', overflowY: 'auto', width: '225px' }}
          >
            {/* None option */}
            <Dropdown.Item
              onClick={() => handleSelect('')}
              active={!value || value === ''}
              style={{ fontWeight: !value || value === '' ? 'bold' : 'normal' }}
            >
              None
            </Dropdown.Item>

            <Dropdown.Divider />

            {/* Question mark group */}
            <Dropdown.Header style={{ fontWeight: 'bold', paddingLeft: '12px' }}>
              {iconOptions.question_mark.icon} {iconOptions.question_mark.label}
            </Dropdown.Header>
            {Object.entries(iconOptions.question_mark.colors).map(([colorKey, colorOption]) => (
              <Dropdown.Item
                key={colorOption.url}
                onClick={() => handleSelect(colorOption.url)}
                active={value === colorOption.url}
                style={{
                  paddingLeft: '24px',
                  fontWeight: value === colorOption.url ? 'bold' : 'normal',
                }}
              >
                {colorOption.label}
              </Dropdown.Item>
            ))}

            {/* Information group */}
            <Dropdown.Header style={{ fontWeight: 'bold', paddingLeft: '12px' }}>
              {iconOptions.information.icon} {iconOptions.information.label}
            </Dropdown.Header>
            {Object.entries(iconOptions.information.colors).map(([colorKey, colorOption]) => (
              <Dropdown.Item
                key={colorOption.url}
                onClick={() => handleSelect(colorOption.url)}
                active={value === colorOption.url}
                style={{
                  paddingLeft: '24px',
                  fontWeight: value === colorOption.url ? 'bold' : 'normal',
                }}
              >
                {colorOption.label}
              </Dropdown.Item>
            ))}

            {/* Exclamation group */}
            <Dropdown.Header style={{ fontWeight: 'bold', paddingLeft: '12px' }}>
              {iconOptions.exclamation.icon} {iconOptions.exclamation.label}
            </Dropdown.Header>
            {Object.entries(iconOptions.exclamation.colors).map(([colorKey, colorOption]) => (
              <Dropdown.Item
                key={colorOption.url}
                onClick={() => handleSelect(colorOption.url)}
                active={value === colorOption.url}
                style={{
                  paddingLeft: '24px',
                  fontWeight: value === colorOption.url ? 'bold' : 'normal',
                }}
              >
                {colorOption.label}
              </Dropdown.Item>
            ))}
          </Dropdown.Menu>
        </Dropdown>
      </div>
    </Fragment>
  );
};
