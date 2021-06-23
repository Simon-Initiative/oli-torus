/* eslint-disable react/prop-types */
import React from 'react';
import { Form, OverlayTrigger, Tooltip } from 'react-bootstrap';

interface SchemaOptions {
  label?: string;
  input_width?: string | number;
}
export interface Schema {
  type: string;
  description?: string;
  format?: string;
  options?: SchemaOptions;
  default?: any;
  properties?: Record<string, Schema>;
  items?: Schema;
}
interface PropertyEditorProps {
  schema: Schema;
  value: any;
}

const PropertyEditor: React.FC<PropertyEditorProps> = ({ schema, value }) => {
  const rootProps = schema.properties || {};
  // for now just using properties, but going to need to make a recursive schema renderer
  const inputs = Object.keys(rootProps).map((schemaKey) => {
    const { description, format, options, type, default: defaultValue } = rootProps[schemaKey];

    const label = options?.label || schemaKey;

    // TODO: base different editors off of type
    let controlType = 'text';
    if (type === 'string') {
      if (format === 'email') {
        controlType = 'email';
      }
    }
    if (type === 'number') {
      controlType = 'number';
    }
    if (type === 'boolean') {
      // render checkbox instead
    }

    const controlValue = (value && value[schemaKey]) || defaultValue;

    return (
      <Form.Group key={schemaKey} controlId={`form_${schemaKey}`}>
        <Form.Label>
          {label}
          {description && (
            <OverlayTrigger
              placement="top"
              delay={{ show: 150, hide: 150 }}
              overlay={
                <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                  {description}
                </Tooltip>
              }
            >
              <i className="fa fa-question-circle ml-1" />
            </OverlayTrigger>
          )}
        </Form.Label>
        <Form.Control
          size="sm"
          type={controlType}
          placeholder={`Enter ${label}`}
          defaultValue={controlValue}
        />
      </Form.Group>
    );
  });
  return <Form>{inputs}</Form>;
};
export default PropertyEditor;
