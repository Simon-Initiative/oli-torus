import React, { useEffect, useRef, useState } from 'react';
import { sanitizeRichLabelHtml } from '../../../utils/richOptionLabel';

export interface DropdownRichSelectProps {
  id: string;
  prompt?: string;
  optionLabels: string[];
  /** 1-based index, or <= 0 when showing prompt / none */
  selectedIndex: number;
  disabled: boolean;
  onChange: (oneBasedIndex: number) => void;
  style?: React.CSSProperties;
  className?: string;
}

const menuStyle: React.CSSProperties = {
  position: 'absolute',
  top: '100%',
  left: 0,
  right: 0,
  width: '100%',
  minWidth: 0,
  maxWidth: '100%',
  boxSizing: 'border-box',
  zIndex: 3000,
  maxHeight: 280,
  overflowY: 'auto',
  overflowX: 'hidden',
  margin: 0,
  padding: 0,
  borderRadius: '0 0 4px 4px',
  border: '1px solid rgba(0,0,0,.15)',
  backgroundColor: '#fff',
  listStyle: 'none',
};

const triggerStyle: React.CSSProperties = {
  width: '100%',
  minHeight: 38,
  height: 38,
  boxSizing: 'border-box',
  display: 'flex',
  alignItems: 'center',
  textAlign: 'left',
  padding: '0.375rem 2.25rem 0.375rem 0.75rem',
  lineHeight: 1.5,
  border: '1px solid #000',
  borderRadius: 4,
  backgroundColor: '#fff',
  color: '#212529',
  backgroundImage:
    "url(\"data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3e%3cpath fill='none' stroke='%23343a40' stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='m2 5 6 6 6-6'/%3e%3c/svg%3e\")",
  backgroundRepeat: 'no-repeat',
  backgroundPosition: 'right 0.75rem center',
  backgroundSize: '16px 12px',
};

/**
 * Accessible custom dropdown that can render sanitized HTML in options (native select cannot).
 */
export const DropdownRichSelect: React.FC<DropdownRichSelectProps> = ({
  id,
  prompt,
  optionLabels,
  selectedIndex,
  disabled,
  onChange,
  style,
  className,
}) => {
  const [open, setOpen] = useState(false);
  // 0 = prompt (when provided), 1..N = option labels
  const [activeIndex, setActiveIndex] = useState<number>(-1);
  const wrapRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) {
      return;
    }
    const close = (e: MouseEvent) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, [open]);

  const sanitized = optionLabels.map((l) => sanitizeRichLabelHtml(l || ''));
  const sanitizedPrompt = sanitizeRichLabelHtml(prompt || '');
  const hasPrompt = Boolean(sanitizedPrompt);
  const totalOptions = optionLabels.length;

  const showPromptInButton = selectedIndex <= 0;
  const triggerHtml = showPromptInButton ? sanitizedPrompt : sanitized[selectedIndex - 1] ?? '';

  const getDefaultActiveIndex = () => {
    if (hasPrompt) {
      return selectedIndex <= 0 ? 0 : selectedIndex;
    }
    // Without prompt, ensure we always point to a real option.
    if (selectedIndex > 0) {
      return selectedIndex;
    }
    return totalOptions > 0 ? 1 : -1;
  };

  useEffect(() => {
    if (!open) {
      return;
    }
    setActiveIndex((prev) => (prev >= 0 ? prev : getDefaultActiveIndex()));
    // Intentionally do not depend on selection changes while open; native <select> keeps focus on the control.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  useEffect(() => {
    if (!open || activeIndex < 0) {
      return;
    }
    const activeId =
      activeIndex === 0 ? `${id}-option-prompt` : `${id}-option-${activeIndex}`;
    document.getElementById(activeId)?.scrollIntoView?.({ block: 'nearest' });
  }, [activeIndex, id, open]);

  return (
    <div
      ref={wrapRef}
      className={`janus-dropdown-rich position-relative${className ? ` ${className}` : ''}`}
      style={{ width: '100%', ...style, zIndex: open ? 2000 : undefined }}
    >
      <style>{`
        .janus-dropdown-rich-trigger:focus,
        .janus-dropdown-rich-trigger:focus-visible {
          border-color: rgb(0, 101, 134);
          outline: 0;
          box-shadow: 0 0 0 0.25rem rgba(0, 101, 134, 0.25);
        }
        .janus-dropdown-rich-trigger:disabled {
          background-color: #e9ecef;
          opacity: 1;
          cursor: not-allowed;
        }
        .janus-dropdown-rich-menu li {
          padding: 6px 16px;
          cursor: pointer;
          white-space: normal;
          word-break: break-word;
          color: #212529;
        }
        .janus-dropdown-rich-menu li:hover {
          background-color: gray;
          color: #fff;
        }
        .janus-dropdown-rich-menu li.is-selected {
          background-color: #6c757d;
          color: #fff;
        }
        .janus-dropdown-rich-menu li.is-active {
          background-color: gray;
          color: #fff;
        }
        .janus-dropdown-rich-menu li.is-prompt {
          color: #6c757d;
        }
        .janus-dropdown-rich-menu .janus-rich-dropdown-option-inner p {
          display: inline;
          margin: 0;
        }
      `}</style>

      <button
        type="button"
        id={`${id}-select`}
        className="janus-dropdown-rich-trigger"
        style={triggerStyle}
        disabled={disabled}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={`${id}-listbox`}
        aria-disabled={disabled}
        aria-activedescendant={
          activeIndex <= -1
            ? undefined
            : activeIndex === 0
              ? `${id}-option-prompt`
              : `${id}-option-${activeIndex}`
        }
        onClick={() => !disabled && setOpen((o) => !o)}
        onKeyDown={(e) => {
          if (disabled) {
            return;
          }

          if (e.key === 'Escape') {
            if (open) {
              e.preventDefault();
              setOpen(false);
            }
            return;
          }

          if (e.key === 'Tab') {
            if (open) {
              setOpen(false);
            }
            return;
          }

          // Open interactions.
          if (!open) {
            if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
              e.preventDefault();
              const base = getDefaultActiveIndex();
              if (e.key === 'ArrowDown') {
                const next = hasPrompt ? (base === 0 ? 1 : base + 1) : base + 1;
                setActiveIndex(Math.min(next, totalOptions || 1));
              } else {
                const prev = hasPrompt ? base - 1 : base - 1;
                const min = hasPrompt ? 0 : 1;
                setActiveIndex(Math.max(prev, min));
              }
              setOpen(true);
              return;
            }
            if (e.key === 'Enter' || e.key === ' ') {
              e.preventDefault();
              setOpen(true);
              return;
            }
            return;
          }

          // Navigation/selection when open.
          if (e.key === 'ArrowDown') {
            e.preventDefault();
            const base = activeIndex < 0 ? getDefaultActiveIndex() : activeIndex;
            const next = base + 1;
            const max = hasPrompt ? totalOptions : totalOptions;
            setActiveIndex(Math.min(next, max));
            return;
          }

          if (e.key === 'ArrowUp') {
            e.preventDefault();
            const base = activeIndex < 0 ? getDefaultActiveIndex() : activeIndex;
            const prev = base - 1;
            const min = hasPrompt ? 0 : 1;
            setActiveIndex(Math.max(prev, min));
            return;
          }

          if (e.key === 'Home') {
            e.preventDefault();
            setActiveIndex(hasPrompt ? 0 : totalOptions > 0 ? 1 : -1);
            return;
          }

          if (e.key === 'End') {
            e.preventDefault();
            setActiveIndex(hasPrompt ? totalOptions : totalOptions);
            return;
          }

          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            const base = activeIndex < 0 ? getDefaultActiveIndex() : activeIndex;
            if (base === 0 && hasPrompt) {
              setOpen(false);
              return;
            }
            if (base > 0 && base <= totalOptions) {
              onChange(base);
              setOpen(false);
            }
          }
        }}
      >
        <span
          className="flex-grow-1 janus-rich-dropdown-option-inner text-truncate"
          dangerouslySetInnerHTML={{ __html: triggerHtml || '\u00a0' }}
        />
      </button>

      {open ? (
        <ul
          id={`${id}-listbox`}
          role="listbox"
          className="janus-dropdown-rich-menu"
          style={menuStyle}
          aria-activedescendant={
            activeIndex <= -1
              ? undefined
              : activeIndex === 0
                ? `${id}-option-prompt`
                : `${id}-option-${activeIndex}`
          }
        >
          {/* Prompt as first item — mirrors native disabled first <option> */}
          {sanitizedPrompt ? (
            <li
              role="option"
              aria-selected={false}
              aria-disabled
              className={activeIndex === 0 ? 'is-prompt is-active' : 'is-prompt'}
              id={`${id}-option-prompt`}
              onMouseDown={(e) => e.preventDefault()}
              onClick={() => setOpen(false)}
            >
              <span
                className="janus-rich-dropdown-option-inner"
                dangerouslySetInnerHTML={{ __html: sanitizedPrompt }}
              />
            </li>
          ) : null}

          {sanitized.map((labelHtml, index) => {
            const oneBased = index + 1;
            const isSelected = selectedIndex === oneBased;
            return (
              <li
                key={oneBased}
                role="option"
                aria-selected={isSelected}
                className={
                  isSelected ? 'is-selected' : activeIndex === oneBased ? 'is-active' : ''
                }
                id={`${id}-option-${oneBased}`}
                onMouseDown={(e) => e.preventDefault()}
                onClick={() => {
                  setOpen(false);
                  setActiveIndex(oneBased);
                  onChange(oneBased);
                }}
              >
                <span
                  className="janus-rich-dropdown-option-inner"
                  dangerouslySetInnerHTML={{ __html: labelHtml }}
                />
              </li>
            );
          })}
        </ul>
      ) : null}
    </div>
  );
};
