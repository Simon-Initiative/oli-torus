import React, { useEffect, useRef, useState } from 'react';

/* Slate uses a deferred update mechanism when you call updateModel.
   that works great for most use cases, but if you're doing a standard
   input field with a value & onchange handler, the cursor position
   will get reset on changes because of that. This is a workaround
   input field that will manually remember the cursor position. */

interface Props {
  value: string;
  onChange: (v: string) => void;
  [key: string]: any;
}

export const CursorInput: React.FC<Props> = ({ value, onChange, ...props }) => {
  const [cursor, setCursor] = useState<null | number>(null);
  const ref = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (ref.current) {
      ref.current.setSelectionRange(cursor, cursor);
    }
  }, [ref, cursor, value]);

  return (
    <input
      ref={ref}
      type="text"
      {...props}
      value={value}
      onChange={(e) => {
        setCursor(e.target.selectionStart);
        onChange(e.target.value);
      }}
    />
  );
};
