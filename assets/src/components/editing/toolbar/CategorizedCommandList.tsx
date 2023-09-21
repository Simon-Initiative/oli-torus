import React from 'react';
import {
  CommandCategories,
  CommandCategoryList,
  CommandDescription,
} from '../elements/commands/interfaces';
import styles from './Toolbar.modules.scss';
import { DescriptiveButton } from './buttons/DescriptiveButton';

interface CategorizedCommandListProps {
  commands: CommandDescription[];
}

// Optional label translations for the short-category names
const labels: Record<CommandCategories, string> = {
  Language: 'Language Learning',
  Formatting: 'Text Formatting',
};

const categorizeCommands = (commands: CommandDescription[]) => {
  return commands.reduce((acc: { [category: string]: CommandDescription[] }, curr) => {
    const category = curr.category || 'Other';
    acc[category] = [...(acc[category] || []), curr];
    return acc;
  }, {});
};

export const CategorizedCommandList: React.FC<CategorizedCommandListProps> = ({ commands }) => {
  const categorizedCommands = categorizeCommands(commands);
  return (
    <div>
      {CommandCategoryList.filter((category) => !!categorizedCommands[category]).map(
        (category, i) => (
          <CommandCategory key={i} category={category} commands={categorizedCommands[category]} />
        ),
      )}
    </div>
  );
};

interface CommandCategoryProps {
  category: string;
  commands: CommandDescription[];
}

const CommandCategory: React.FC<CommandCategoryProps> = ({ category, commands }) => {
  return (
    <div>
      <div className={styles.toolbarLabel}>{labels[category] || category}:</div>
      {commands.map((command, i) => (
        <DescriptiveButton key={i} description={command} />
      ))}
    </div>
  );
};
