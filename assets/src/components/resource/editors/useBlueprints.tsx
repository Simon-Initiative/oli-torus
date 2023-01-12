import React from 'react';
import { useEffect, useMemo, useState } from 'react';
import guid from 'utils/guid';
import { Editor, Node, Transforms } from 'slate';
import {
  CommandDescription,
  Command,
  CommandContext,
} from '../../editing/elements/commands/interfaces';
import { ModelTypes } from '../../../data/content/model/elements/types';

interface Blueprint {
  name: string;
  description: string;
  content: {
    blueprint: any[];
  };
  icon: string;
}

// Any element with an id attribute gets a new value set for that attribute, recursive through children.
export const generateIds = (
  elements: { type: ModelTypes; id?: string; children: any[] }[],
): Node[] => {
  const withIds = elements.map((element) => {
    if ('id' in element) {
      const id = guid();
      const children: any = element.children && generateIds(element.children);
      return { ...element, id, children };
    } else {
      const children: any = element.children && generateIds(element.children);
      return { ...element, children };
    }
  });
  return withIds as unknown as Node[];
};

export const useBlueprints = () => {
  const [blueprints, setBlueprints] = useState<Blueprint[]>([]);

  useEffect(() => {
    const fetchBlueprints = async () => {
      const response = await fetch('/api/v1/blueprint');
      const data = await response.json();
      if (data.result === 'success' && data.rows) {
        setBlueprints(data.rows);
      }
    };

    fetchBlueprints();
  }, []);

  return blueprints;
};

export const useBlueprintCommandDescriptions = (): CommandDescription[] => {
  const blueprints = useBlueprints();
  const commands = useMemo(() => (blueprints || []).map(blueprintToCommand), [blueprints]);
  return commands;
};

const createBlueprintCommand = (blueprint: Blueprint): Command => {
  return {
    precondition: (_editor: Editor) => true,
    execute: (context: CommandContext, editor: Editor) => {
      const at = editor.selection as any;
      const content = generateIds(blueprint.content.blueprint);
      Transforms.insertNodes(editor, content, { at });
    },
  };
};

const blueprintToCommand = (blueprint: Blueprint): CommandDescription => ({
  type: 'CommandDesc',
  icon: () => <i className={blueprint.icon}></i>,
  command: createBlueprintCommand(blueprint),
  description: () => blueprint.name,
  active: () => false,
});
