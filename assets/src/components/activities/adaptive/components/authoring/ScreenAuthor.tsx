import CustomFieldTemplate from 'apps/authoring/components/PropertyEditor/custom/CustomFieldTemplate';
import PropertyEditor from 'apps/authoring/components/PropertyEditor/PropertyEditor';
import partSchema, {
  partUiSchema,
  transformModelToSchema as transformPartModelToSchema,
} from 'apps/authoring/components/PropertyEditor/schemas/part';
import { AnyPartComponent } from 'components/parts/types/parts';
import { JSONSchema7 } from 'json-schema';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Col, Container, Row } from 'react-bootstrap';
import { clone } from 'utils/common';
import AddPartToolbar from './AddPartToolbar';
import LayoutEditor from './LayoutEditor';

interface ScreenAuthorProps {
  screen: any;
}

const screenSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    Position: {
      type: 'object',
      title: 'Dimensions',
      properties: {
        x: { type: 'number' },
        y: { type: 'number' },
        z: { type: 'number' },
      },
    },
    Size: {
      type: 'object',
      title: 'Dimensions',
      properties: {
        width: { type: 'number' },
        height: { type: 'number' },
      },
    },
    palette: {
      type: 'object',
      properties: {
        backgroundColor: { type: 'string', title: 'Background Color' },
        borderColor: { type: 'string', title: 'Border Color' },
        borderRadius: { type: 'string', title: 'Border Radius' },
        borderStyle: { type: 'string', title: 'Border Style' },
        borderWidth: { type: 'string', title: 'Border Width' },
      },
    },
  },
};

const screenUiSchema = {
  'ui:title': 'Feedback Window',
  Position: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Position',
    x: {
      classNames: 'col-4',
    },
    y: {
      classNames: 'col-4',
    },
    z: {
      classNames: 'col-4',
    },
  },
  Size: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Dimensions',
    width: {
      classNames: 'col-6',
    },
    height: {
      classNames: 'col-6',
    },
  },
  palette: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Background & Border',
    backgroundColor: {
      'ui:widget': 'ColorPicker',
    },
    borderColor: {
      'ui:widget': 'ColorPicker',
    },
    borderStyle: { classNames: 'col-6' },
    borderWidth: { classNames: 'col-6' },
  },
};

const ScreenAuthor: React.FC<ScreenAuthorProps> = ({ screen }) => {
  const [currentScreenData, setCurrentScreenData] = useState(screen);

  const [screenWidth, setScreenWidth] = useState(screen.custom.width);
  const [screenHeight, setScreenHeight] = useState(screen.custom.height);
  const [screenBackgroundColor, setScreenBackgroundColor] = useState(
    screen.custom.palette.backgroundColor || 'lightblue',
  );

  const [selectedPartId, setSelectedPartId] = useState('');

  const [partsList, setPartsList] = useState<AnyPartComponent[]>([]);

  useEffect(() => {
    console.log('SA:Screen Changed', { screen });
    setCurrentScreenData(screen);
    setPartsList([...screen.partsLayout]);
    setScreenHeight(screen.custom.height);
    setScreenWidth(screen.custom.width);
  }, [screen]);

  const [currentPropertySchema, setCurrentPropertySchema] = useState<JSONSchema7>(screenSchema);
  const [currentPropertyUiSchema, setCurrentPropertyUiSchema] = useState<any>(screenUiSchema);
  const [currentPropertyData, setCurrentPropertyData] = useState<any>({});

  useEffect(() => {
    if (!selectedPartId) {
      // current should be screen, formatted to match the schema
      console.log('screen selected', currentScreenData);
      const data = {
        Position: {
          x: currentScreenData.custom.x || 0,
          y: currentScreenData.custom.y || 0,
          z: currentScreenData.custom.z || 0,
        },
        Size: {
          width: currentScreenData.custom.width,
          height: currentScreenData.custom.height,
        },
        palette: {
          backgroundColor: currentScreenData.custom.palette.backgroundColor,
          borderColor: currentScreenData.custom.palette.borderColor,
          borderRadius: currentScreenData.custom.palette.borderRadius,
          borderStyle: currentScreenData.custom.palette.borderStyle,
          borderWidth: currentScreenData.custom.palette.borderWidth,
        },
      };
      setCurrentPropertyData(data);
      setCurrentPropertySchema(screenSchema);
      setCurrentPropertyUiSchema(screenUiSchema);
    } else {
      const part = partsList.find((part: AnyPartComponent) => part.id === selectedPartId);
      if (part) {
        const PartClass = customElements.get(part.type);
        if (PartClass) {
          const partInstance = new PartClass() as any;
          if (partInstance.getSchema) {
            const customPartSchema = partInstance.getSchema();

            const mergedPartSchema: JSONSchema7 = {
              ...partSchema,
              properties: {
                ...partSchema.properties,
                custom: { type: 'object', properties: { ...customPartSchema } },
              },
            };

            setCurrentPropertySchema(mergedPartSchema);
          } else {
            setCurrentPropertySchema(partSchema);
          }

          if (partInstance.getUiSchema) {
            const customPartUiSchema = partInstance.getUiSchema();
            const mergedUiSchema = {
              'ui:title': 'Selected Part',
              ...partUiSchema,
              custom: {
                'ui:ObjectFieldTemplate': CustomFieldTemplate,
                'ui:title': 'Custom',
                ...customPartUiSchema,
              },
            };

            setCurrentPropertyUiSchema(mergedUiSchema);
          } else {
            setCurrentPropertySchema(partSchema);
          }

          let data = clone(part);
          if (partInstance.transformModelToSchema) {
            // because the part schema below only knows about the "custom" block
            data.custom = { ...data.custom, ...partInstance.transformModelToSchema(data.custom) };
          }
          data = transformPartModelToSchema(data);
          setCurrentPropertyData(data);
        }
      }
    }
  }, [selectedPartId, currentScreenData, partsList]);

  const handleEditorChange = useCallback(
    (parts: any[]) => {
      console.log('FEEDBACK: EDITOR CHANGE', { parts });
      const newScreenData = clone(currentScreenData);
      newScreenData.partsLayout = parts;
      setCurrentScreenData(newScreenData);
      setPartsList(parts);
    },
    [currentScreenData],
  );

  const handleEditorSelect = (partId: string) => {
    console.log('SA:LE SELECT', { partId });
    setSelectedPartId(partId);
  };

  const handlePropertyEditorChange = useCallback(
    (properties: any) => {
      console.log('SA:PE:Change', properties);
      const newScreenData = clone(currentScreenData);
      if (!selectedPartId) {
        // modifying screen properties
        const newWidth = properties.Size.width;
        const newHeight = properties.Size.height;
        setScreenWidth(newWidth);
        setScreenHeight(newHeight);
        newScreenData.custom.width = newWidth;
        newScreenData.custom.height = newHeight;
      } else {
        // modifying part properties
      }

      setCurrentScreenData(newScreenData);
    },
    [currentScreenData, partsList, selectedPartId],
  );

  // TODO: this is for feedback and popup, configure for other things somewhere
  const allowedParts = [
    'janus_text_flow',
    'janus_image',
    'janus_audio',
    'janus_video',
    'janus_capi_iframe',
  ];

  const handleAddPart = useCallback(
    (part: AnyPartComponent) => {
      const parts = [...partsList, part];
      console.log('SA:AddPart', { part, partsList, parts });
      setPartsList(parts);
      setSelectedPartId(part.id);
    },
    [partsList],
  );

  const canvasRef = useRef<any>(null);

  return (
    <Container>
      <Row style={{ padding: 2, borderBottom: '2px solid #eee' }}>
        <Col>
          <AddPartToolbar
            partTypes={allowedParts}
            priorityTypes={allowedParts}
            onAdd={handleAddPart}
          />
        </Col>
      </Row>
      <Row style={{ minHeight: (currentScreenData.custom.height || 0) + 100 }}>
        <Col ref={canvasRef} className="canvas-dots" style={{ paddingTop: 50, paddingBottom: 50 }}>
          <LayoutEditor
            id="screen-designer-1"
            hostRef={canvasRef.current}
            width={screenWidth}
            height={screenHeight}
            backgroundColor={screenBackgroundColor}
            parts={partsList}
            selected={selectedPartId}
            onChange={handleEditorChange}
            onSelect={handleEditorSelect}
          />
        </Col>
        <Col sm={3}>
          <PropertyEditor
            schema={currentPropertySchema}
            uiSchema={currentPropertyUiSchema}
            value={currentPropertyData}
            onChangeHandler={handlePropertyEditorChange}
          />
        </Col>
      </Row>
    </Container>
  );
};

export default ScreenAuthor;
