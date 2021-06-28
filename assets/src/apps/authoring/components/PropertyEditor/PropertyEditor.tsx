/* eslint-disable react/prop-types */
import React, { Fragment } from 'react';
import Form from "@rjsf/core";
import { JSONSchema7 } from "json-schema";

interface PropertyEditorProps {
  schema: JSONSchema7;
  value: any;
}

const PropertyEditor: React.FC<PropertyEditorProps> = ({ schema, value }) => {
  return (
    <Form schema={schema} formData={value} >
      <Fragment />{/*  this one is to remove the submit button */}
    </Form>
  );
};
export default PropertyEditor;
