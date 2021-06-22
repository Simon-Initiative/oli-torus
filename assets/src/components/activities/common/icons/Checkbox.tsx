import React from 'react';

const Checked = () => (
  <i
    style={{
      color: '#00bc8c',
      fontSize: '30px',
      cursor: 'pointer',
    }}
    className="material-icons-outlined"
  >
    check_box
  </i>
);

const Unchecked = () => (
  <i
    style={{
      color: 'rgba(0,0,0,0.26)',
      fontSize: '30px',
      cursor: 'pointer',
    }}
    className="material-icons-outlined"
  >
    check_box_outline_blank
  </i>
);

export const Checkbox = {
  Checked,
  Unchecked,
};
