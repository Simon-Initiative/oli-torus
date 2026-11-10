# Draft spec

# **Math Eval Engine: Draft Spec (Torus)**

## **Goal**

Enable robust, configurable evaluation of learner math inputs across OLI Torus activities with clear author controls, reliable grading semantics, and actionable feedback. Support phased delivery so MVP can ship quickly and existing questions do not need to be rebuilt.

## **Positioning**

**Type:** Evaluation type, not a new activity type.  
**Why:**

* Works inside existing question types and avoids recreating legacy items.  
* Supports multi input problems by attaching multiple evaluators to a single item.  
* Keeps rendering and author workflow unchanged while upgrading grading.

## **MVP Scope (Phase 1\)**

1. Answer formats: [Exact forms for common constructs: integer, rational, simplified fraction](#bookmark=id.9o4jw94yzog8)  
2. Equivalence checks  
   * [Numeric equality with tolerance (abs, relative)](#bookmark=id.mybmus4ngz6)  
   * [Value equivalence](#bookmark=id.3q92diaeikiu)  
   * [value equivalence via AST, normalization and random point sampling](#bookmark=id.f14071dnqpq9) (n \= 8\)  
3. Units (optional flag): [Accept numeric with unit (good for Physics, Chemistry, dimensional analysis, etc)](#bookmark=id.e0lin67l8wy2)  
4. Author controls  
   * [Tolerance configuration: abs=0.001, rel=0.1 percent](#bookmark=id.m5x3yv1snpmj)  
   * [Required form: simplified fraction, integer, rational, decimal with precision (author configurable)](#bookmark=id.ibwoyk8b34cv)   
   * [Variables allowed and their domains](#bookmark=id.ctjpux26cl86)  
5. Feedback and scoring: Targeted feedback by rule match (e.g., unsimplified fraction, unit missing, wrong unit, domain violation)  
6. Validation and preview: [Lint warnings for unreachable rules or conflicting settings](#bookmark=id.utlarycyyc9j)

## 

## 

## **Phase 2**

* Multi part algebra with shared variables  
* Significant figures and precision policies  
* Exact form enforcement beyond simple rationals (e.g., factored, expanded)  
* Composite numbers and vectors, simple matrices  
* Rich unit systems and custom unit definitions  
* Enhanced partial credit with weighted rule groups  
* Per learner hints based on error patterns  
* Allowed functions and symbols  
* Require specific unit or accept from a list with auto conversion

## **Phase 3**

* Step checking and line by line evaluation  
* Differential and integral recognition for calculus  
* Expression style constraints with configurable complexity budget  
* Graph and geometry inputs  
* Programmatic variant generation  
* Domain checks (e.g., denominator not zero, variable in allowed set)

---

## **Details** 

### Equality Semantics (MVP) 

1. **Numeric**  
   * Input parsed to float with unit strip if configured.  
   * Compare with abs or relative tolerance. Relative uses max(|ref|, eps) for stability.  
   * Optional rounding policy for author display only.  
2. **Algebraic**  
   * Parse to AST. Normalize: remove whitespace, canonicalize multiplication and exponentiation.  
   * Random point sampling across variable domains for N points (default N=8).  
     All samples must satisfy numeric equivalence within a tight internal tolerance.  
   * Optional lightweight normalization: constant folding, commutative reorder, basic factor expand where safe.  
   * Domain guards evaluated before equivalence. Division by zero or invalid domain fails with targeted feedback.  
3. **Units**  
   * Parse unit tokens. Convert to canonical SI for comparison.  
   * If unit required and missing: rule match `unit_missing`.  
   * If wrong but convertible unit: feedback includes expected unit.  
4. **Form constraints**  
   * Simplified fraction check: numerator and denominator coprime and denominator positive.  
   * Integer only: no decimal point and within safe range.  
   * Decimal places: regex match and numeric reparse.

### Multi Input Support

* Allow an item to declare multiple named inputs with individual `math-eval` configs.  
* Optional cross input constraints in Phase 2 (e.g., x+y=10 across two fields).  
* Scoring aggregation: sum of parts or all or nothing per item, set by author.

### Feedback and Partial Credit

* Rule evaluation runs in order. First match can stop or continue, configured by `rule_mode: first|accumulate`.  
* Common predefined rules in library:  
  * `unsimplified_fraction`  
  * `missing_unit`  
  * `wrong_unit_convertible`  
  * `sign_error_linear`  
  * `extraneous_root`  
  * `domain_violation`  
  * `rounding_only_off`  
* Authors can add regex or predicate based rules with parameters.

### Data, Telemetry, and Analytics

* Store raw input, parsed form, normalized form hash, matched rule id, score, evaluation time, and unit status.

### Acceptance Criteria for MVP

1. Algebraic equivalence via sampling passes a test suite of 200 common identities and fails 200 near miss cases.  
2. Numeric tolerance works for absolute and relative with unit conversions for SI base units.  
3. Authors can configure, preview, and publish without editing activity type.  
4. Multi input item with two fields each using `math-eval` evaluates independently and logs analytics.  
5. Partial credit rules work with both first match and accumulate modes.  
6. Evaluation average latency under 20 ms for typical inputs on server profile X.

### Team and Inputs Needed

* **Content authors** for rule library seeds and real test cases from existing courses.  
* **QA** for golden sets and adversarial near miss cases.

## **Open Questions to Resolve Quickly**

1. Default variable domain for algebraic sampling when author does not specify. Proposed: integer in \[-5, 5\] excluding 0 where forbidden.  
2. Default tolerance for numeric. Proposed: abs 1e-3 or rel 1e-2 whichever is looser, with author override.  
3. Units in MVP. Include or defer. If included, restrict to SI base plus derived common physics units.  
4. Storage of normalized form. Hash only or full AST for replay.

# Open Source Feature compare

| Evaluation Feature | STACK | WeBWorK (MathObjects) | Open edX CAPA | LON-CAPA | IMathAS |
| :---- | ----- | ----- | ----- | ----- | ----- |
| **Algebraic equivalence** (AST \+ normalization \+ sampling) | ✅ Best-in-class, Maxima-backed | ✅ Numeric and symbolic equivalence | ⚠ Basic algebraic support, relies on Python evals | ⚠ Some symbolic rules but limited | ✅ Supports algebraic answers, robustness varies |
| **Domain checks** (avoid division by zero etc.) | ✅ Very strong | ✅ Built-in domain validations | ❌ Mostly absent or basic | ⚠ Partial | ✅ Some support |
| **Numeric evaluation with tolerances** (abs/relative) | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Significant figures enforcement** | ⚠ Research plugins exist | ✅ Good support via flags | ❌ Not native | ✅ Yes (common in physics content) | ✅ Available |
| **Units and dimensional consistency** | ⚠ Pilot support via Maxima | ⚠ Add-ons exist | ❌ Weak unit handling | ✅ Best support historically | ✅ Good support |
| **Function equality** (compare f(x) \= g(x)) | ✅ Yes (Maxima symbolic) | ✅ Via formula objects \+ sampling | ⚠ Limited | ⚠ Partial | ✅ Via numeric sampling |
| **Matrices and vectors** | ✅ Yes (symbolic \+ numeric) | ✅ Strong for vectors/matrices | ❌ Very weak | ✅ Some but older APIs | ✅ Some structural support |
| **Partial credit with rule-based feedback** | ✅ Potential-response trees | ✅ Configurable answer checkers | ⚠ Limited | ✅ Yes, scriptable | ✅ Rule sets available |
| **Authoring controls (allowed functions, variables, form constraints)** | ✅ Granular control | ✅ Strong config | ⚠ Basic in UI | ⚠ Older UI model | ✅ Good author controls |
| **Analytics hooks** | ❌ Minimal | ❌ Minimal | ✅ Strong pipeline | ✅ Some logging | ✅ Some logging |
| **Multi-input and typed responses** | ✅ Yes | ✅ Yes | ✅ Yes | ⚠ Varies | ✅ Yes |

# Appendix

## **Accept numeric with unit**

Sometimes the content goal is not only the number, but also the unit the learner uses (especially in physics, chemistry, and engineering contexts).

Example:

* Correct answer: `9.8 m/s²`

If a student types:

| Student Answer | Result | Reason |
| ----- | ----- | ----- |
| 9.8 | ❌ | Missing unit |
| 9.8 m/s² | ✅ | Numeric \+ correct unit |
| 9.80 m/s2 | ✅ | Equivalent numeric and unit formatting |
| 980 cm/s² | ✅ | Convertible to correct unit |
| 9.8 ft/s² | ❌ | Not an accepted unit system |

Key behaviors behind “accept numeric with unit”

When this option is enabled, the evaluator must:

1. Parse two components  
   * A numeric value  
   * A unit string  
2. Normalize the numeric value  
   * Account for precision rules and tolerance  
3. Normalize the unit  
   * Convert to a canonical form (SI usually)  
   * Check that unit is in accepted set  
4. Apply conversion if allowed  
   * `cm` → `m` by dividing by 100  
   * Then check numeric correctness again  
5. Error-specific feedback  
   * If unit missing → “Include a unit”  
   * If wrong but convertible unit → “Use correct unit”  
   * If incompatible system → “Unit not accepted”

Author options

These are common configuration choices:

| Setting | Description | Example |
| ----- | ----- | ----- |
| Unit required | Answer must include a unit | `m/s²` required |
| Accepted units | List of allowed/convertible units | `m/s²`, `cm/s²` |
| Strict unit | Only one correct unit is allowed | Must be `m/s²` |
| Value only | Ignore units entirely | Great for pure math |

## 

## **Exact Form Rules** 

This phrase is about **not just the numeric value**, but **the way the student writes the answer**.

Sometimes 0.5 is mathematically equal to ½, but the instructor may want one specific format.

#### Exact Form Requirements: What They Mean

| Author Requirement | Examples Accepted | Examples Rejected | Why |
| ----- | ----- | ----- | ----- |
| **Integer only** | `7`, `-3` | `3.5`, `7/1` | Must be whole number, no decimals |
| **Rational number** | `3/4`, `-5/2` | `0.75` | Must be a fraction, not decimal |
| **Simplified fraction** | `4/5` | `8/10` | Fraction must be simplified, numerator & denominator coprime |

#### Why authors need this

Correctness sometimes includes **precision and learning outcomes**. Example:

* If the skill objective is **fraction simplification**, then `8/10` should not score full credit.

Other examples:

* Chemistry: require integer coefficient ratios  
* Physics: require values without unit unless instructed  
* Math: require simplified radical form such as `√2` instead of `1.414...`

#### How the evaluator enforces this

It looks at:

* **Representation type** (integer, fraction)  
* **Properties** (coprime numerator/denominator, no decimals)  
* **Exactness** (not rounded)

Examples:

* Student: `0.3333`  
* Correct: `1/3`  
* Numerically close but **not allowed** if exact rational form required.

#### Simple one-liner for your spec

**Exact form checks ensure the student expresses their answer in the author-required representation, such as integer-only, rational-only, or simplified fraction form.**

## **Numeric Equality with Tolerance**

1\. Absolute Tolerance

Checks if two numbers differ by less than a fixed amount.

Author sets:

* Correct answer: `5.0`  
* Absolute tolerance: `0.1`

Student answers:

| Student Answer | Difference | Correct? |
| ----- | ----- | ----- |
| 5.08 | 0.08 | ✅ Yes (0.08 ≤ 0.1) |
| 4.92 | 0.08 | ✅ Yes |
| 4.85 | 0.15 | ❌ No |

Good for:  
• Values near zero  
• Simple decimal answers

2\. Relative Tolerance

Checks percentage difference rather than fixed difference.

Author sets:

* Correct answer: `100`  
* Relative tolerance: `1 percent` → difference ≤ 1 percent of 100 \= 1

Student answers:

| Student Answer | % Error | Correct? |
| ----- | ----- | ----- |
| 100.5 | 0.5 percent | ✅ Yes |
| 101.1 | 1.1 percent | ❌ No |
| 99.2 | 0.8 percent | ✅ Yes |

Good for:  
• Scaling with magnitude  
• Physics and engineering questions

Why both?

Some numbers are tiny:

Correct: `0.002`  
Relative tolerance 1 percent \= ±0.00002  
Student: `0.003` → relative error too large  
Absolute tolerance might be better there.

Systems usually evaluate:

* Both modes available  
* Author chooses which applies  
* Or “whichever looser is allowed” if configured

---

## **Numeric Equivalence with Scientific Notation Normalization**

(also called **value equivalence**)

The evaluator strips formatting differences like how scientific notation is written. It just evaluates the underlying numeric value.

### **Why it works:**

`6 × 10^7 = 60,000,000`  
`60 × 10^6 = 60,000,000`

Same value → ✅ Correct

---

#### How it's categorized in the spec terms you’ve been building:

| Equivalence Type | Applies Here? | Why |
| ----- | ----- | ----- |
| **Numeric Equivalence** | ✅ Yes | Values are equal |
| **Scientific Notation Normalization** | ✅ Yes | Converts exponent forms consistently |
| Symbolic Equivalence | ⚠ Probably not used | No variables or algebraic structure |
| Tolerance | Not needed here | They are exactly equal |
| Exact Form Enforcement | ❌ Not required | Written differently but still accepted |

If scientific notation were **not** allowed as a form:

* Still correct **if** only value matters  
* Might lose credit **if** form rules are enforced (like integer only)

---

#### How to describe this in your spec

Values expressed in scientific notation are normalized and compared numerically, so equivalent representations like 6×1076×107 and 60×10660×106 are considered correct when form constraints do not forbid scientific notation.

You can include this example under **Numeric Evaluation** and **Form Rules**.

## Algebraic Equivalence Checking

There are three major steps:

### 1\. **AST \= Abstract Syntax Tree**

The expression is converted into a structured math representation.  
It breaks the expression into operators and operands.

Example:  
Input: `2x + 6`

AST looks more like:

(+)

 |--- (\* 2 x)

 |--- 6

This structure allows the system to:  
• Understand operations  
• Compare meaning rather than text shape  
• Apply symbolic rules

### 

### **2\. Normalization**

This is like cleaning up both expressions into a consistent structure.

Examples of normalization rules:  
• Remove unnecessary parentheses  
• Put terms in a consistent order (x before constants)  
• Simplify constants (3+2 → 5\)  
• Canonical formatting of multiplication (`2*x` not `x*2`, etc.)

Normalization catches simple cases where expressions are just formatted differently.

### **3\. Random Point Sampling**

This is the clever part.

Instead of symbolically proving the expressions are equal (hard problem), the system:

1. Chooses several values for the variables (like x=1, x=3, x=-2)  
2. Plugs those into:  
   * The student’s expression  
   * The author’s correct expression  
3. Compares the results

If the values match for **every** sample, the system assumes the two expressions are equivalent.

Example:

| x | Student: `2x + 6` | Correct: `2(x+3)` |
| ----- | ----- | ----- |
| 1 | 8 | 8 |
| \-2 | 2 | 2 |
| 5 | 16 | 16 |

So they’re equivalent.

This avoids the complexity of a full symbolic algebra engine.

### Why random sampling?

Symbolic math systems like SymPy or Maxima are heavier and slower.  
Sampling is:  
• Fast  
• Good enough for most educational uses  
• Used by platforms like STACK, WeBWorK, IMathAS

You can make it safe by:  
• Testing multiple random points  
• Avoiding values that break the expression (division by zero)  
• Tight numeric tolerance checks

### It fails only in rare corner cases

For example:  
`(x^2 - 1)/(x - 1)` and `x + 1`

These look equivalent, but the first one is **undefined at x \= 1**.  
Sampling across random points can catch this if domain checks are included, which is planned in your spec.

### In one sentence

#### Why all three are needed

| Without AST | Might fail on complex structure |  
| Without Normalization | Might mark equivalent answers as different |  
| Without Sampling | Might miss equal-but-different-looking expressions |

You protect correctness by combining all three.

#### One-line summary (for your spec)

**AST \+ normalization \+ sampling** means we structurally parse student and correct expressions, simplify them to a standard form, and then verify they produce the same numeric results across multiple valid input points.

## **Tolerance configuration: abs=0.001, rel=0.1 percent**

This line is describing how strictly we judge a numeric answer to be “close enough” to the expected value.

Tolerance configuration means the evaluator allows small differences due to rounding, measurement, or decimal formatting.

Here is the exact meaning of that example:

* abs \= 0.001  
  The student’s answer can differ by up to 0.001 from the correct number  
  Example:  
  Correct \= 5  
  Acceptable student answers \= 5.001, 4.999, 4.9985 (as long as difference ≤ 0.001)  
* rel \= 0.1 percent  
  The student’s answer can differ by up to 0.1 percent of the correct value  
  Example:  
  Correct \= 200  
  0.1 percent of 200 \= 0.2  
  Acceptable answers \= 199.8 to 200.2

Relative tolerance scales depending on the magnitude of the correct answer, so it avoids unfair scoring on large numbers.

#### Why we need both

If the correct answer is a very small number like 0.002

Absolute tolerance 0.001 is fine  
Relative tolerance 0.1 percent \= 0.000002, which is too strict

If the correct answer is a large number like 50000

Absolute tolerance 0.001 is meaningless  
Relative tolerance 0.1 percent \= 50, which is reasonable

So the evaluator picks whichever makes sense based on the configuration authors choose.

#### One sentence for your spec

Tolerance settings define how close a numeric input must be to the correct value, using either an absolute allowed difference or a relative percentage difference to ensure fair grading across different numeric scales.

## Required Form (Author-Configurable)

These rules apply after numeric/algebraic correctness is confirmed.  
They control how the student must express the answer.

1\) Simplified Fraction

* Must be a fraction in lowest terms  
* Denominator must be positive  
* Improper fractions allowed unless disabled  
* Examples  
  * ✅ `4/5`, `-7/3`  
  * ❌ `8/10`, `0.8`, `-4/-5`  
* Feedback example: “Simplify your fraction.”

2\) Integer

* Whole number only  
* Decimal or fractional input not allowed  
* Optional:  
  * Range enforcement  
  * Scientific notation allowed/not allowed  
* Examples  
  * ✅ `7`, `0`, `-3`  
  * ❌ `3.0`, `2/1`, `1e3` (if sci-notation disabled)  
* Feedback example: “Enter a whole number.”

3\) Rational (Fraction)

* Must be written as `numerator/denominator`  
* Simplification not required unless paired with simplified flag  
* Examples  
  * ✅ `8/10`, `-5/2`  
  * ❌ `0.8` unless decimals-as-rationals enabled  
* Feedback example: “Write your answer as a fraction.”

4\) Decimal with Precision

* Must use decimal notation  
* Author configures precision:  
  * Exactly `N` decimal places  
  * At least / at most `N` decimal places  
  * Strict vs lenient rounding  
* Examples (exactly 2 decimal places)  
  * ✅ `0.80`, `3.14`  
  * ❌ `0.8`, `3.140`, `4/5`  
* Feedback example: “Use exactly 2 decimal places.”

## Variables Allowed and Their Domains

**These settings control:**

1. **Which variables a student is permitted to use in their answer**  
2. **What numeric values those variables are allowed to take during evaluation (sampling)**

**This protects against unexpected expressions and ensures evaluation is valid.**

#### 1\) Allowed Variables

**Authors specify which variable names can appear.**

**Example:**

**`Allowed variables: x, y`**

**Student answers:**

* **✅ `2x + 3`**  
* **❌ `2z + 3` (z is not permitted)**

**Use cases:**  
**• Keep problems focused**  
**• Prevent symbol-injection or unsupported math**  
**• Avoid using symbols not used in the question stem**

#### 2\) Variable Domain

**Defines what values the variable can take when the evaluator checks equivalence via sampling.**

**Example domain settings:**

**`x ∈ [−5, 5], integer values only`**

**`y ∈ [1, 10], exclude 0`**

**This ensures:**  
**• No division by zero errors during sampling**  
**• No radical-log issues outside valid ranges**  
**• Fairness in equivalence testing**

#### Example Scenarios

| Requirement | Domain | What it prevents |
| ----- | ----- | ----- |
| **Rational expressions** | **Exclude denominator becoming 0** | **`(x^2 - 1)/(x - 1)` illegal at x=1** |
| **Square roots** | **x ≥ 0** | **Avoid complex number results** |
| **Logarithms** | **x \> 0** | **Avoid undefined values** |
| **Trigonometry** | **Specific ranges if necessary** | **Avoid tangent vertical asymptotes** |

#### In Plain Language

**The instructor tells the system which variables students are allowed to use and what values those variables are allowed to take so that evaluation is mathematically valid.**

#### Suggested Author UI

**`Variables:`**

**`[x] x   Domain: [ -5 ] to [ 5 ]   [integer only]`**

**`[ ] y   Domain: [    ] to [   ]   [exclude 0]`**

**`Add variable [+]`**

**Extra toggles:**

*  **Allow only real numbers**  
*  **Allow only integers**  
*  **Exclude singularities automatically**  
*  **Auto-detect domain from correct-answer structure**

#### Targeted Feedback Examples

* **“You used a variable that is not part of this problem.”**  
* **“Expression invalid for some values of x within the expected domain.”**  
* **“Avoid division by zero for x \= 2.”**

## Lint warnings for unreachable rules or conflicting settings

What it is  
Static checks on the evaluator config that warn authors about rules that will never fire or settings that contradict each other.

Why it matters  
Prevents silent grading errors and confusing author experiences.

**Common lints**

1. Unreachable feedback rules  
* Pattern rule never triggers because an earlier broader rule captures all those cases  
* Example:  
  * Rule 1: if value incorrect → feedback A  
  * Rule 2: if unit missing → feedback B  
  * If Rule 1 runs in first-match mode and fires on every incorrect value, Rule 2 will never run  
* Lint: “Rule ‘unit\_missing’ is unreachable. Move it before a catch-all rule or switch to accumulate mode.”  
2. Conflicting required forms  
* Example:  
  * Required form \= Integer  
  * Also required form \= Decimal with precision 2  
* Lint: “Form conflict. Choose one of \[Integer, Rational, Simplified fraction, Decimal\].”  
3. Tolerance contradictions  
* Example:  
  * abs tolerance 0 and relative tolerance 0.05 percent  
  * Value near zero triggers impossible relative threshold  
* Lint: “Relative tolerance too strict near zero. Consider abs ≥ 1e−6 or disable relative near zero.”  
4. Units misconfiguration  
* Example:  
  * Units required \= true  
  * Accepted set is empty  
* Lint: “Units required but no accepted units provided.”  
5. Variable domain issues  
* Example:  
  * Sampling domain includes singularities for the correct answer  
  * x in \[−1, 1\] while correct answer has denominator (x)  
* Lint: “Domain intersects singularity at x=0. Exclude 0 or adjust domain.”  
6. Rule order risk  
* First-match mode with a late specific rule  
* Lint: “Specific rule ‘unsimplified\_fraction’ appears after a general incorrect rule. Reorder to ensure expected feedback.”  
7. Inconsistent scoring  
* Partial credit rule gives score greater than full credit or negative  
* Lint: “Invalid score 1.2. Must be between 0 and 1.”  
8. Algebraic check without variables  
* Checks configured for algebraic equivalence while no variables allowed  
* Lint: “Algebraic sampling configured but no variables present. Disable sampling or add variables.”  
9. Decimal precision and tolerance clash  
* Decimal with precision 2 plus tight absolute tolerance that rejects values rounded to 2 places  
* Lint: “Tolerance 1e−5 conflicts with required 2 decimal places. Consider lenient rounding mode.”  
10. Mixed numbers without fraction form  
* Allow mixed numbers while required form is decimal  
* Lint: “Mixed number input cannot satisfy decimal-only format.”

UI sketch

`[Lint checks]`

`⚠ Rule 'unit_missing' is unreachable due to Rule 'incorrect_catch_all'`

`⚠ Relative tolerance of 0.1% may reject near-zero values. Add abs tolerance ≥ 1e−6`

`⚠ Units required but no accepted units defined`

`[Fix suggestions]  [Re-run lints]`

Auto-fix suggestions

* Reorder rules to move specific rules above catch-all  
* Insert default abs tolerance near zero  
* Populate accepted units with the unit from correct answer  
* Switch rule mode from first-match to accumulate

Acceptance criteria

* Lints run on every save and in the preview panel  
* Each lint has a clear message, location, and suggested fix  
* No publish if severity \= error  
* Warnings can publish but are visible to authors  
* API returns lint list so CI or content QA can validate offline

---

## **API and Integration**

* **Evaluator contract**  
  * Input: candidate string, evaluator config, optional context (seed, locale).  
  * Output: `{isCorrect, score, feedbackId, feedbackText, details}`.  
* **Runtime**  
  * Pure function implementation to allow sandboxing.  
  * Deterministic sampling with seeded RNG for reproducibility.  
* **Localization**  
  * Feedback strings are key based for i18n.  
* **Accessibility**  
  * Math input supports keyboard only paths and screen readers.  
* **Security**  
  * AST parser whitelists symbols and functions.  
  * Strict resource limits and timeouts.

# From Norm (Chatgpt)

# **Math Answer Evaluation Specification**

## **1\. Purpose and Scope**

This specification defines the architecture, behavior, and interoperability requirements for evaluating mathematical answers and expressions within the courseware platform. It supports both numeric and symbolic responses and aims to provide robust, explainable, and extensible evaluation consistent with academic standards.

### **Objectives**

·      Evaluate mathematical expressions for correctness and equivalence.

·      Support multiple input and answer types (numeric, symbolic, function, matrix, etc.).

·      Offer partial credit and targeted feedback.

·      Provide deterministic, sandboxed evaluations for reliability and security.

---

## **2\. Authoring Model**

A **question** consists of three key components: \- **Inputs:** The student’s response entry point. \- **Tests:**Evaluation logic that defines what constitutes a correct or partially correct answer. \- **Feedback Rules:**Conditional responses and scoring weights triggered by evaluation outcomes.

Example JSON representation:

{  
  "input": {"type": "math\_expression", "id": "ans1"},  
  "tests": \[  
    {"id": "equiv", "type": "algebraic\_equivalence", "expected": "x^2 \+ 2x \+ 1"},  
    {"id": "domain", "type": "domain\_check", "valid": "x \!= \-1"}  
  \],  
  "feedback": \[  
    {"when": "\!equiv", "message": "Your expression is not equivalent to the expected form."}  
  \]  
}

---

## **3\. Input and Parsing**

### **Accepted Syntax**

·      Implicit multiplication, parentheses, exponents (^), absolute values, factorials.

·      Standard mathematical functions (sin, cos, tan, log, etc.).

·      Constants: pi, e.

### **User Interface**

·      Plaintext parser supporting LaTeX or ASCII input.

·      Real-time rendering via MathJax or KaTeX.

·      Syntax validation with user-facing error messages.

---

## **4\. Evaluation Mechanisms**

### **4.1 Algebraic Equivalence**

Two expressions A and B are equivalent if they simplify to the same canonical form. Evaluation proceeds as: 1\. Parse both expressions into an abstract syntax tree (AST). 2\. Simplify (factoring, cancelling, normalization of commutative operations). 3\. Compare symbolic forms. 4\. If inconclusive, perform numeric equivalence testing via randomized sampling.

Sampling configuration: \- Domain: default \[-5, 5\] (over reals, unless constrained). \- Points: minimum 5, maximum 10\. \- Pass threshold: 100% match within tolerance.

### **4.2 Numeric Evaluation**

Numeric answers are evaluated using the following: \- **Tolerance:** absolute or relative. \- **Significant figures:**optionally enforced. \- **Units:** optional (see section 4.4).

Example:

{"expected": 3.1416, "tolerance": {"type": "relative", "value": 0.001}}

### **4.3 Function Equality**

Functions are equivalent if: \- Symbolically identical, or \- Evaluate to the same values at randomly chosen domain points (excluding singularities).

### **4.4 Units & Dimensions**

·      Parse recognized SI and derived units.

·      Normalize expressions into canonical base units.

·      Mark answers incorrect if dimensionally inconsistent.

·      Allow equivalent conversions (e.g., 1 m ≡ 100 cm).

### **4.5 Matrices and Vectors**

·      Compare shape, then element-wise equality (numeric or symbolic per entry).

·      Allow tolerance for floating-point entries.

---

## **5\. Feedback and Partial Credit**

### **Mechanism**

Each test emits one of {pass, fail, error} and an optional feedback message.

### **Potential Response Trees**

·      Conditional evaluation structure:

o   If all tests pass → full credit.

o   If certain patterns fail (e.g., sign error, missing factor) → partial credit.

o   If syntax error → feedback for invalid expression.

Example partial credit rule:

{"when": "missing\_factor(x)", "score": 0.5, "message": "You omitted the factor x."}

---

## **6\. Authoring and Validation**

### **Randomization**

Authors may define symbolic parameters (e.g., a, b, c) and specify bounds or sets for random generation.

### **Validation Tools**

·      Preview and test-run all randomized variants.

·      Automated detection of invalid expressions or unsolvable cases.

---

## **7\. Security and Sandboxing**

·      All symbolic and numeric computations run in isolated environments (e.g., containerized Maxima/SymPy service).

·      CPU, memory, and execution time limits enforced.

·      Random seeds logged for reproducibility.

---

## **8\. Extensibility**

### **Pluggable Answer Tests**

Each test type implements: \- **Input contract:** expected and optional parameters. \- **Evaluation function:**(student\_answer, expected\_answer, options) \-\> result. \- **Metadata:** version, author, description.

Supported test types (initial set): \- numeric\_equality \- algebraic\_equivalence \- function\_equivalence \- domain\_check \- units\_equivalence

### **Extension Hooks**

Developers can register new test modules via a plugin interface with versioned schemas.

---

## **9\. Interoperability**

### **API Contracts**

Math evaluations are invoked through a stateless API endpoint:

POST /evaluate/math  
{  
  "student": "x^2 \+ 2x \+ 1",  
  "expected": "(x \+ 1)^2",  
  "tests": \["algebraic\_equivalence"\]  
}

Response:

{"result": "pass", "score": 1.0, "feedback": "Equivalent expression."}

### **Content Format Compatibility**

·      Import/export compatibility with Open edX OLX, Moodle XML, and QTI numeric response schemas.

---

## **10\. Logging and Analytics**

·      Log every evaluation request and result for audit.

·      Capture anonymized error patterns to improve feedback rules.

---

## **11\. Quality Assurance**

·      Unit tests for each evaluation type.

·      Benchmark suite covering edge cases (domain restrictions, trig identities, undefined points).

·      Continuous regression testing using a canonical question bank.

---

## **12\. References**

·      STACK documentation (Moodle plugin)

·      WeBWorK MathObjects design

·      LON-CAPA formula and numeric response specifications

·      Open edX CAPA problem model

·      PrairieLearn external grader API

## **13\. Implementation Notes (Elixir/OTP)**

### **13.1 Architecture Overview**

·      **Language/Runtime:** Elixir on BEAM with OTP supervision.

·      **Frameworks:** Phoenix (HTTP API), Ecto (PostgreSQL), Oban (optional async jobs), Telemetry/Metrics.

·      **Boundary Contexts:**

o   MathEval (public API/context; orchestrates evaluations)

o   MathEval.Parsing (AST \+ normalization)

o   MathEval.Tests (pluggable answer tests)

o   MathEval.Sampling (deterministic numeric sampling)

o   MathEval.Units (dimensional analysis & conversions)

o   MathEval.CAS (CAS adapter(s) for symbolic work)

o   MathEval.Feedback (rules & partial credit)

o   MathEval.Store (Ecto schemas & persistence)

o   MathEval.Telemetry (events/metrics/log enrichment)

**High-level flow:** 1\. HTTP request → MathEval validates payload → builds evaluation plan. 2\. For each test: parse inputs → run symbolic check via CAS (if configured) → fall back or complement with Sampling. 3\. Aggregate results → run Feedback rules → persist via Store → respond.

### **13.2 Supervision Tree (ASCII)**

MathEval.Application (Supervisor)  
├─ MathEval.Repo (Ecto.Repo)  
├─ MathEval.Telemetry (Telemetry Supervisor)  
├─ {Phoenix.PubSub, name: MathEval.PubSub}  
├─ MathEvalWeb.Endpoint (Phoenix)  
├─ MathEval.CAS.Pool (DynamicSupervisor)  
│  └─ MathEval.CAS.Worker (Task.Supervisor/Poolboy optional)  
├─ MathEval.Sampling.RNG (GenServer, seeded PRNG per node)  
└─ Oban (optional, for batch jobs)

### **13.3 Public Elixir API (Context)**

defmodule MathEval do  
  @moduledoc """  
  *Public API for evaluating math answers.*  
  """  
  alias MathEval.{Planner, Store}

  @spec evaluate(map()) :: {:ok, Store.EvaluationResult.t()} | {:error, term()}  
  def evaluate(%{"student" \=\> s, "expected" \=\> e, "tests" \=\> tests} \= params) do  
    with {:ok, plan} \<- Planner.plan(params),  
         {:ok, result} \<- Planner.execute(plan) do  
      {:ok, Store.persist\_result(result)}  
    end  
  end  
end

### **13.4 HTTP API (Phoenix)**

**Routes** \- POST /api/v1/evaluate – single evaluation \- POST /api/v1/grade-batch – batch evaluations (async if Obanenabled) \- GET /api/v1/health – health/heartbeat

**Controller sketch**

defmodule MathEvalWeb.EvaluateController do  
  use MathEvalWeb, :controller

  def create(conn, params) do  
    case MathEval.evaluate(params) do  
      {:ok, res} \-\> json(conn, MathEvalWeb.View.result(res))  
      {:error, reason} \-\> conn |\> put\_status(422) |\> json(%{error: inspect(reason)})  
    end  
  end  
end

**Request example**

{  
  "student": "x^2 \+ 2x \+ 1",  
  "expected": "(x+1)^2",  
  "tests": \[  
    {"type": "algebraic\_equivalence", "options": {"use\_cas": true}},  
    {"type": "domain\_check", "options": {"valid": "x \!= \-1"}}  
  \],  
  "seed": 42  
}

**Response example**

{  
  "result": "pass",  
  "score": 1.0,  
  "details": \[  
    {"id": "algebraic\_equivalence", "status": "pass", "evidence": {"symbolic": true, "numeric\_points": 0}},  
    {"id": "domain\_check", "status": "pass"}  
  \],  
  "feedback": \["Equivalent expression."\],  
  "meta": {"duration\_ms": 23, "seed": 42}  
}

### **13.5 Data Model (Ecto)**

*\# Evaluation request and results*  
schema "evaluations" do  
  field :student, :string  
  field :expected, :string  
  field :tests, :map        *\# ordered list*  
  field :seed, :integer  
  field :result, :string    *\# pass | fail | error*  
  field :score, :float  
  field :details, :map      *\# per-test evidence*  
  field :feedback, {:array, :string}  
  timestamps()  
end

*\# Feedback rules (author-defined)*  
schema "feedback\_rules" do  
  field :name, :string  
  field :predicate, :string *\# DSL or JSON logic*  
  field :score\_weight, :float  
  field :message, :string  
  field :active, :boolean, default: true  
  timestamps()  
end

*\# Units catalog (UCUM/SI subset)*  
schema "units" do  
  field :symbol, :string  
  field :dimension, :string *\# e.g., "L^1 T^-2"*  
  field :to\_base\_factor, :float  
  field :offset, :float, default: 0.0  
  timestamps()  
end

**Indexes & constraints** \- evaluations(result, inserted\_at) for analytics. \- feedback\_rules(name, active) unique partial index. \- units(symbol) unique index.

### **13.6 Parsing & AST**

·      Parser implemented with **NimbleParsec** → token stream → AST nodes {:add, left, right}, {:pow, base, exp}, etc.

·      Normalization passes:

o   Constant folding, coefficient collection, sort-commutative (mult/add), canonical trig/log names.

o   Domain extraction (e.g., denominators, even roots, logs) → constraints set.

defmodule MathEval.Parsing do  
  @type ast :: any()  
  @spec parse\!(String.t()) :: ast  
  @spec normalize(ast) :: ast  
end

### **13.7 Pluggable Tests**

Each test implements the behaviour:

defmodule MathEval.Tests.Behaviour do  
  @callback id() :: atom()  
  @callback run(student :: String.t(), expected :: String.t(), opts :: map()) ::  
            {:pass, map()} | {:fail, map()} | {:error, term()}  
end

**Built-ins** \- AlgebraicEquivalence – CAS simplify \+ structural compare; fallback to numeric sampling. \- NumericEquality – absolute/relative/ULP tolerance; optional significant figures. \- FunctionEquivalence – pointwise compare over domain; pole-aware sampling. \- DomainCheck – ensures student expression respects constraints. \- UnitsEquivalence – parse, reduce to base units, compare dimensions & magnitude.

### **13.8 Numeric Sampling (Deterministic)**

·      PRNG: :rand.exsplus seeded with request seed (or derived from payload hash).

·      Default domain \[-5, 5\], configurable per variable; exclude singularities via domain constraints.

defmodule MathEval.Sampling do  
  @spec points(variables :: \[atom()\], n :: pos\_integer(), seed :: integer(), domain :: map()) :: \[map()\]  
end

### **13.9 CAS Integration**

·      **Adapter behaviour:**

defmodule MathEval.CAS.Adapter do  
  @callback simplify(expr :: String.t()) :: {:ok, String.t()} | {:error, term()}  
  @callback equivalent?(a :: String.t(), b :: String.t()) :: {:ok, boolean()} | {:error, term()}  
end

·      **HTTP service option:** sandboxed Python (SymPy/Maxima) container. Configurable via:

config :math\_eval, MathEval.CAS.HTTP,  
  base\_url: "http://cas:8080",  
  pool\_size: 8,  
  timeout\_ms: 1500

·      Resource limits enforced on CAS container (CPU/mem/time); propagate failure as {:fail, %{reason: :timeout}} and continue with numeric checks when possible.

### **13.10 Units & Dimensions**

·      Units table seeded via migration; conversions computed by factoring to base SI and applying offsets where applicable (e.g., °C↔K).

·      DSL: "m\*s^-2" → parse → dimension vector. Reject mismatched dimensions before magnitude comparison.

### **13.11 Feedback Rules Engine**

·      Rule predicates evaluated against test outcomes and expression features (e.g., missing\_factor(:x), sign\_error()).

·      Minimal DSL example:

%{  
  "all" \=\> \[  
    {"test", "algebraic\_equivalence", "fail"},  
    {"feature", "has\_common\_factor", "x"}  
  \]  
}

·      Rules produce {delta\_score, messages}; aggregated with cap at \[0.0, 1.0\].

### **13.12 Telemetry & Observability**

Emit events: \- \[:math\_eval, :evaluate, :start|:stop|:exception\] \- \[:math\_eval, :cas, :request, :stop\] (duration, outcome) \- \[:math\_eval, :test, :run, :stop\] (id, status)

Attach metrics (Prometheus/StatsD): p95 latency, CAS timeout rate, parse error rate, sampling retries.

### **13.13 Configuration**

config :math\_eval,  
  cas\_adapter: MathEval.CAS.HTTP,  
  numeric: \[points: 7, rel\_tol: 1.0e-8, abs\_tol: 1.0e-10\],  
  function: \[points: 9, domain: %{"x" \=\> \[-3, 3\]}\],  
  units: \[strict: true\],  
  max\_duration\_ms: 2000

### **13.14 Security**

·      All CAS calls in a network-isolated container with read-only FS; denylist for eval/IO.

·      Input size limits; AST depth limits; timeout guards; circuit breaker around CAS pool.

·      Deterministic seeds recorded to reproduce evaluations.

### **13.15 Testing Strategy**

·      **Property tests** (StreamData): equivalence invariants (e.g., a+b \== b+a).

·      **Golden tests**: fixed seeds for tricky identities (trig, rational simplification, piecewise).

·      **Fuzzing**: random expression generation against both CAS and internal normalizer; assert agreement.

### **13.16 Migration Snippets**

def change do  
  create table(:evaluations) do  
    add :student, :text  
    add :expected, :text  
    add :tests, :map  
    add :seed, :bigint  
    add :result, :string  
    add :score, :float  
    add :details, :map  
    add :feedback, {:array, :text}  
    timestamps()  
  end  
  create index(:evaluations, \[:result, :inserted\_at\])  
end

### **13.17 Batch Grading (Optional)**

·      Oban job MathEval.Jobs.GradeBatch consumes a list of items; progress via PubSub.

·      API returns job id; polling endpoint GET /api/v1/grade-batch/:id returns partials.

### **13.18 Deployment Notes**

·      Run Phoenix and CAS container separately; configure connection pool.

·      Horizontal scale: stateless web; CAS pool per node; RNG seed derived from evaluation id.

·      Blue/green deploy with zero-downtime migrations for units/rules tables.

### **13.19 Example End-to-End Test (ExUnit)**

test "algebraic equivalence with domain" do  
  params \= %{  
    "student" \=\> "x^2+2x+1",  
    "expected" \=\> "(x+1)^2",  
    "tests" \=\> \[  
      %{ "type" \=\> "algebraic\_equivalence", "options" \=\> %{ "use\_cas" \=\> true } },  
      %{ "type" \=\> "domain\_check", "options" \=\> %{ "valid" \=\> "x \!= \-1" } }  
    \],  
    "seed" \=\> 1337  
  }  
  assert {:ok, res} \= MathEval.evaluate(params)  
  assert res.result \== "pass"  
  assert res.score \== 1.0  
end

# JIRA and Slack discussions

JIRA discussions 

I've looked into how other platforms handle similar functionality. Here are some relevant examples:

* Learnosity's symbolic equivalence feature: [Learnosity equivSymbolic](https://authorguide.learnosity.com/hc/en-us/articles/360000437798-equivSymbolic)  
* Illuminate Education's math equation response item: [Illuminate Create a Math Equation](https://support.illuminateed.com/hc/en-us/articles/360041882153-Create-a-Math-Equation-Response-Item)  
* Wiris Quizzes validation options: [Wiris Validation Options](https://docs.wiris.com/quizzes/en/validation-options.html)

### 

### 

### **Anders Weinstein**

September 9, 2024 at 2:55 PM  
Torus does not support checking for equivalence of math keyboard input questions. Legacy OLI did not support this either.

 The math input question type is for use when you want a particular symbolic mathematical expression which appears neatly typeset. Behind the scenes it works by using a math keyboard to construct a LaTeX expression and comparing the LaTex expression *as a string* with a correct answer LaTeX string that are specified. That makes this question type EXTREMELY fragile against equivalent formulations, and of rather limited utility. At best one could try to handle equivalent formulations by specifying multiple likely forms of the answer using the multiple correct answer feature available through targeted feedback.

To allow for numerically equivalent inputs, it would be better to define this as a numerical input question, which will then accept any numerically-equivalent expression. This would require students to use the computer-oriented E-notation form to express scientific notation, rather than a version with multiplication signs and exponents as shown above. This is the approach in Chemistry, for example.

