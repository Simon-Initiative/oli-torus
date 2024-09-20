import React, { useState } from 'react';
import { Button } from 'react-bootstrap';
import Spinner from 'react-bootstrap/Spinner';
import { ApplicationMode } from '../../../store/app/slice';
import { D6 } from './D6';
import { D20 } from './D20';
import { Landscape } from './Landscape';
import { LeftArrow } from './LeftArrow';
import { Portrait } from './Portrait';
import { RightArrow } from './RightArrow';

interface Props {
  onSetupComplete: (mode: ApplicationMode, title: string) => void;
  startStep?: number; // Mostly just for storybook to tell us what step to start on
  initialTitle?: string;
}

export const OnboardWizard: React.FC<Props> = ({ startStep, onSetupComplete, initialTitle }) => {
  const [step, setStep] = useState(startStep || 0);
  const [builderVersion, setBuilderVersion] = useState(0);
  const [lessonType, setLessonType] = useState(1);
  const [title, setTitle] = useState(initialTitle || '');

  const commitChanges = () => {
    setStep(3);
    onSetupComplete(builderVersion === 1 ? 'flowchart' : 'expert', title);
  };

  return (
    <div className="onboard-wizard">
      <div className="wizard-window">
        {step === 0 && <Step1 title={title} setTitle={setTitle} onNext={() => setStep(1)} />}
        {step === 1 && (
          <Step2
            selected={builderVersion}
            setSelected={setBuilderVersion}
            onNext={() => setStep(2)}
            onBack={() => setStep(0)}
          />
        )}

        {step === 2 && builderVersion === 2 && (
          <Step3Advanced onNext={commitChanges} onBack={() => setStep(1)} />
        )}

        {step === 2 && builderVersion === 1 && (
          <Step3
            selected={lessonType}
            setSelected={setLessonType}
            onNext={commitChanges}
            onBack={() => setStep(1)}
          />
        )}

        {step === 3 && <Working />}
      </div>
    </div>
  );
};

const Working: React.FC = () => {
  return (
    <div className="wizard-content">
      <h1 className="wizard-header">3. Advanced Authoring</h1>
      <div className="wizard-body working">
        <Spinner animation="border" />
        <span>Working...</span>
      </div>
      <div className="wizard-footer">
        <div className="wizard-step">
          <div className="wizard-step">Step 3/3</div>
        </div>
      </div>
    </div>
  );
};

const Step3Advanced: React.FC<{
  onNext: () => void;
  onBack: () => void;
}> = ({ onNext, onBack }) => {
  return (
    <div className="wizard-content">
      <h1 className="wizard-header">3. Advanced Authoring</h1>
      <div className="wizard-body advanced-author-step">
        <p>
          Recommended for users with experience using html code, json editing, css styling and
          building logic and users ready to take their lessons to the next level
        </p>
        <h2>Allows you to</h2>
        <ul>
          <li>Create multidimensional and extended lessons</li>
          <li>Build complex lesson logic and interactions</li>
          <li>Create advanced conditioning in pathing</li>
          <li>Set complex scoring rules</li>
        </ul>
        <h2>Note</h2>

        <p>
          Projects created in Advanced Authoring do not open in Simple Authoring. This requires
          creating a new lesson project.
        </p>
      </div>
      <div className="wizard-footer">
        <div className="wizard-step">Step 3/3</div>
        <div className="wizard-buttons">
          <Button onClick={onBack} variant="link">
            <LeftArrow />
            Back
          </Button>
          <Button onClick={onNext} variant="link">
            Next
            <RightArrow />
          </Button>
        </div>
      </div>
    </div>
  );
};

const Step3: React.FC<{
  onNext: () => void;
  onBack: () => void;
  selected: number;
  setSelected: (value: number) => void;
}> = ({ onNext, selected, onBack, setSelected }) => {
  return (
    <div className="wizard-content">
      <h1 className="wizard-header">3. Select lesson type</h1>
      <div className="wizard-body">
        <div className="builder-version-options">
          <div
            className={`builder-version-option ${selected === 1 ? 'active' : ''}`}
            onClick={() => setSelected(1)}
          >
            <div className="big-icon">
              <Landscape />
            </div>
            <label>Landscape</label>
            <p>
              Perfect if the lesson will be mostly viewed by students on chromebooks and tablets.
            </p>
          </div>
          <div className={`builder-version-option disabled`}>
            <div className="big-icon">
              <Portrait />
            </div>
            <label className="disabled">Portrait - Coming Soon</label>
            <p>It will work great if most of it will be displayed by students on mobile phones.</p>
          </div>
        </div>
      </div>
      <div className="wizard-footer">
        <div className="wizard-step">Step 3/3</div>
        <div className="wizard-buttons">
          <Button onClick={onBack} variant="link">
            <LeftArrow />
            Back
          </Button>
          <Button disabled={selected === 0} onClick={onNext} variant="link">
            Next
            <RightArrow />
          </Button>
        </div>
      </div>
    </div>
  );
};

const Step2: React.FC<{
  onNext: () => void;
  onBack: () => void;
  selected: number;
  setSelected: (value: number) => void;
}> = ({ onNext, selected, onBack, setSelected }) => {
  return (
    <div className="wizard-content">
      <h1 className="wizard-header">2. Select Builder Version</h1>
      <div className="wizard-body">
        <div className="builder-version-options">
          <div
            className={`builder-version-option ${selected === 1 ? 'active' : ''}`}
            onClick={() => setSelected(1)}
          >
            <div className="big-icon">
              <D6 />
            </div>
            <label>Simple authoring</label>
            <p>Easily build lessons using templates, simplified interactions, and conditioning.</p>
          </div>
          <div
            className={`builder-version-option ${selected === 2 ? 'active' : ''}`}
            onClick={() => setSelected(2)}
          >
            <div className="big-icon">
              <D20 />
            </div>
            <label>Advanced authoring</label>
            <p>Build complex lessons using extended logic rules and CSS editing.</p>
          </div>
        </div>
      </div>
      <div className="wizard-footer">
        <div className="wizard-step">Step 2/3</div>
        <div className="wizard-buttons">
          <Button onClick={onBack} variant="link">
            <LeftArrow />
            Back
          </Button>
          <Button disabled={selected === 0} onClick={onNext} variant="link">
            Next
            <RightArrow />
          </Button>
        </div>
      </div>
    </div>
  );
};

const Step1: React.FC<{
  title: string;
  setTitle: (title: string) => void;
  onNext: () => void;
}> = ({ title, setTitle, onNext }) => {
  return (
    <div className="wizard-content">
      <h1 className="wizard-header">1. Write a title for your lesson</h1>
      <div className="wizard-body">
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          type="text"
          className="title-input"
          placeholder="Enter title..."
        />
      </div>
      <div className="wizard-footer">
        <div className="wizard-step">Step 1/3</div>
        <Button disabled={title.length === 0} onClick={onNext} variant="link">
          Next
          <RightArrow />
        </Button>
      </div>
    </div>
  );
};
