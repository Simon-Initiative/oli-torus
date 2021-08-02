import React, { useCallback, useState } from 'react';
import Konva from 'konva';
import { useLayoutEffect } from 'react';

const textFlowHack = (node: any): any => {
  let nodeText = '';
  if (node?.tag === 'text') {
    nodeText = node.text;
  } else if (node?.children?.length > 0) {
    nodeText = textFlowHack(node?.children[0]);
  } else {
    nodeText = '\n';
  }
  return nodeText;
};

const KonvaStage: React.FC<any> = (props: any) => {
  const { size = { width: 800, height: 600 }, background = { color: '#fff' }, layers = [] } = props;

  const [stage, setStage] = useState<any>(null);
  const containerRef = useCallback((el) => {
    if (el !== null) {
      const _stage = new Konva.Stage({
        width: el.clientWidth,
        height: el.clientHeight,
        container: el,
      });
      setStage(_stage);
    }
  }, []);

  useLayoutEffect(() => {
    if (!stage) {
      return;
    }

    // TODO: optimize rendering so it isn't a full redraw

    const bgLayer = new Konva.Layer({
      x: 300,
      y: 100,
      width: size.width,
      height: size.height,
    });
    bgLayer.add(
      new Konva.Rect({
        x: 0,
        y: 0,
        width: size.width,
        height: size.height,
        fill: background.color,
      }),
    );

    stage.add(bgLayer);

    layers.forEach((layer: any) => {
      const layerRef = new Konva.Layer({
        x: 300,
        y: 100,
        width: size.width,
        height: size.height,
      });
      layer.parts.forEach((part: { id: string; type: string; custom: any }) => {
        const partGroup = new Konva.Group({
          x: part.custom.x,
          y: part.custom.y,
          width: part.custom.width,
          height: part.custom.height,
        });

        // create label
        const label = new Konva.Label({
          x: 0,
          y: 0,
          draggable: false,
        });

        // add a tag to the label
        label.add(
          new Konva.Tag({
            fill: '#bbb',
            stroke: '#333',
            shadowColor: 'black',
            shadowBlur: 10,
            shadowOffset: { x: 5, y: 5 },
            shadowOpacity: 0.2,
            lineJoin: 'round',
            pointerDirection: 'down',
            pointerWidth: 8,
            pointerHeight: 8,
            cornerRadius: 5,
          }),
        );

        // add text to the label
        label.add(
          new Konva.Text({
            text: part.type,
            fontSize: 8,
            lineHeight: 1.2,
            padding: 4,
            fill: 'magenta',
          }),
        );

        partGroup.add(label);

        if (part.type === 'janus-image') {
          Konva.Image.fromURL(part.custom.src, (imgNode: any) => {
            imgNode.setAttrs({
              width: part.custom.width,
              height: part.custom.height,
            });
            partGroup.add(imgNode);
          });
        }

        if (part.type === 'janus-text-flow') {
          let y = 0;
          part.custom.nodes.forEach((node: any) => {
            const text = textFlowHack(node);
            const textNode = new Konva.Text({
              y,
              width: part.custom.width,
              /* height: part.custom.height, */
              text,
              fontSize: 16,
            });
            y = textNode.height() + y + 1;
            partGroup.add(textNode);
          });
        }

        layerRef.add(partGroup);
      });

      stage.add(layerRef);
    });

    return () => {
      stage.clear();
      stage.destroyChildren();
    };
  }, [stage, size, background, layers]);

  return <div style={{ width: '100%', height: '100%' }} ref={containerRef}></div>;
};

export default KonvaStage;
