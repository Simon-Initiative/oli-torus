**LKT-AOA Implementation Proposal**

Selecting and Configuring Student Proficiency Modeling for OLI/Torus

*Tanvi Domadia, Senior Learning Engineer, CMU OLI  |  July 2026*

# **1\. Background** 

This document outlines the proposed deployment configuration of Logistic Knowledge Tracing with All Opportunities Averaged (LKT-AOA; Pavlik et al., 2021; Baker et al., 2023\) for OLI/Torus, based on an empirical comparison of eight models across twelve datasets (\~2,500 students total).

All models were evaluated using 5-fold GroupKFold cross-validation grouped by students, ensuring every model was tested on students unseen during training, which reflects real deployment conditions.

LKT-AOA wins AUC in 10 of 12 datasets and RMSE in 8 of 12 datasets. Elo-M-AOA outperforms on RMSE in 4 of the original OLI datasets \- Statistics, Psychology, French, and Employability, all broad conceptual courses with coarse KC structures. That pattern is itself an interesting finding about per-course model selection. The REAL Chemistry replication is particularly striking: LKT-AOA wins all 6 semesters consistently, across different student cohorts and course levels, with AUC ranging from 0.818 to 0.884 and RMSE from 0.196 to 0.228.

LKT is interpretable, computationally lightweight, and deployable without GPU infrastructure. 

# **2\. Selected Feature Configuration**

LKT predicts P(correct), the probability that a student will answer a specific item correctly, given everything we know about their interaction history with that knowledge component. It's a logistic regression model, which means the output is a weighted sum of features passed through a sigmoid function.

The equation:

logit P(correct) \= βkc ​+ βitem​ \+ γ⋅log(opp+1) \+ ρ. recency\_logit 

Four features, each with a specific role:

| Feature | What it captures | Why it's in the model |
| :---- | :---- | :---- |
| βkc | KC difficulty | Baseline probability of success on this KC, learned from prior student data. Controls for the fact that some KCs are just harder than others. |
| βitem | Item difficulty | Difficulty of this specific question, independent of the KC. This is the feature that separates LKT from PFA \- items within the same KC vary in difficulty, and ignoring that variation conflates KC learning with item effects. |
| log(opp \+ 1\) | Learning rate | How much a student has practiced this KC. Log scale because learning gains decelerate \- the 10th attempt adds less new information than the 1st.  |
| recency\_logit | Recent performance | Exponentially weighted summary of how the student has been doing recently on this KC. Recent opportunities matter more than distant ones. Positive if they've been getting things right lately, negative if they've been struggling. |

## **Recency Logit: the Calculation**

After each attempt, two running scores update with a 0.9 decay factor:

success\_score \= success\_score × 0.9 \+ correct

failure\_score \= failure\_score × 0.9 \+ (1 − correct)

recency\_logit \= log((success\_score \+ 1\) / (failure\_score \+ 1))

The \+1 in the denominator prevents division by zero and keeps the logit from exploding early in a sequence. Both scores initialize at 0 for a new student on a new KC, so the recency logit starts neutral and updates after the first attempt.

## **KC Difficulty: Data Type and Source**

βkc is a single floating point number per KC, learned as a logistic regression coefficient from historical student interaction data.

{kc\_id: string, beta\_kc: float}

* Existing courses: run an initial offline training cycle on existing DataShop data. Upload learned βkc values as an unpublished revision. Author publishes before the next semester.

* New courses: β\_kc defaults to 0 for all KCs until first semester data is collected.

* Retraining cadence: KC difficulty is retrained once per semester: KC-level estimates require more cumulative data to stabilize than item-level estimates.

## **Item Difficulty: How It's Estimated**

βitem is a learned logistic regression coefficient, not a pre-specified value. The model estimates it from historical student performance data during training. Items that students consistently get wrong get negative coefficients; items they consistently get right get positive ones.

This is a simpler approach than full IRT: IRT estimates item difficulty and student ability simultaneously through maximum likelihood, and separates them more cleanly. What we have is a logistic regression approximation that captures the same basic signal with less complexity.

### **Threshold Definition**

Βitem remains at 0 until the following threshold is met:

threshold \= max(10, 0.30 × enrolled\_students) unique students

* For a class of 20 students → max(10, 6\) \= 10 students required

* For a class of 100 students → max(10, 30\) \= 30 students required

* For a class of 200 students → max(10, 60\) \= 60 students required

Rationale: logistic regression coefficient estimation requires at least 10 independent observations for stable parameter estimates, this is the psychometric floor from item parameter estimation literature. The 30% scaling ensures larger courses require proportionally more evidence.

Threshold counts unique students, not total attempts. Multiple attempts by the same student on the same item do not count as independent observations of item difficulty.

Note: Distinct from the N=5 section-level display threshold. N=5 governs when to show a proficiency aggregate to instructors. The item difficulty threshold governs when to estimate a regression coefficient — a statistically more demanding requirement.

### **Item Difficulty Update Cadence**

Βitem is updated via offline batch retraining only, not in real time. A weekly batch job runs with a threshold check, updating βitem only for items that have newly crossed the threshold since the last run. Updated parameters are uploaded as unpublished revisions.

Note: New items default to βitem \= 0\. Empirical Bayes shrinkage, starting from β\_kc as a prior and migrating toward the empirical mean,  is planned as a more principled alternative.

 

# **3\. Two Outputs, Two Different Purposes**

LKT produces a next-step prediction, not a knowledge estimate. P(correct) is asking "what is the probability this student gets this specific item right, right now?" A single item outcome has a lot of variance (guessing, slipping, fatigue) and a single P(correct) value will fluctuate significantly between opportunities.

LKT-AOA addresses this by averaging the model's predictions across all of a student's opportunities on a KC. That averaging smooths out the noise and produces a much more stable estimate of what the student actually knows. Baker et al. (2023) showed that AOA-derived estimates consistently outperform models' own built-in knowledge estimates when predicting post-test performance, which is the metric that actually matters for proficiency decisions.  
So the two outputs serve different purposes:

| Output | Use | Notes |
| :---- | :---- | :---- |
| P(correct) | Adaptive routing, next item selection, remediation triggers | Updated after every attempt. High variance \- not suitable for display to students. |
| LKT-AOA | Student dashboard, instructor view, mastery certification | Averaged across all opportunities on KC. More stable and calibrated. This is what should be displayed. |

## **AOA: Precise Mathematical Definition**

For students on sub-objective k, LKT-AOA is the arithmetic mean of all LKT P(correct) predictions across all n attempts:

LKT-AOA(s,k) \= (1/n) × Σᵢ P(correct)ᵢ

where:

  i            \= 1 to n (attempt index)

  n            \= total attempts by student s on sub-objective k

  P(correct)ᵢ  \= LKT predicted probability on attempt i

The score updates incrementally after each new attempt \- no need to re-average all historical predictions:

LKT-AOA\_new \= ((n-1) × LKT-AOA\_old \+ P(correct)\_n) / n

This incremental update is computationally efficient and suitable for real-time implementation.

# **4\. What the Model Needs**

## **Terminology**

These terms are used consistently throughout this document:

* Attempt: a single student interaction with a single activity. One student answering one question once \= 1 attempt. The same student answering the same question again \= 2 attempts total. All attempts including repeats are used in the proficiency calculation.

* Unique activity: a distinct activity (question) that a student has attempted at least once, regardless of how many times they attempted it. Used only for the confidence calculation \- not for proficiency.

The model requires the following per interaction:

* Student ID (anonymized)  
* KC ID (sub-objective ID), must be from a validated KC model (see Section 5\)  
* Item ID (Step Name in DataShop), needed for item intercepts  
* Correct / Incorrect outcome  
* Timestamp, needed for ordering opportunities (time-based decay is a future option)  
* Hint requests, HINT\_REQUEST rows in the transaction log, optional for now

# **5\. Training and Validation**

The model is trained using logistic regression (scikit-learn, saga solver, C=1.0) on historical DataShop interaction logs. Hyperparameters were fixed across all datasets (C=1.0, max\_iter=300). Per-dataset tuning is planned for a future iteration.

Validation used 5-fold GroupKFold cross-validation grouped by student throughout, the same split applied to every model in the comparison. It means models are evaluated on students they've never seen in training, which is the right analog for how the model will be used in production (trained on prior semester data, deployed on new students). Temporal cross-validation (training on prior semesters, testing on the most recent) is planned as an additional validation approach alongside GroupKFold. 

For deployment, the model runs in two modes:

* Pre-trained parameters: KC intercepts, item intercepts, and regression coefficients fit on prior semester data before the course begins. These are static during the semester.  
* Online features: opportunity count and recency logit computed in real time after each attempt. No retraining needed per attempt. The model adapts to individual students through these running features even though the weights are fixed.

Recommended retraining cadence: KC and item intercepts should be retrained at the start of each new semester using all available prior data. The recency logit updates automatically in real time.

## **5.1 Retraining Cycle**

For the initial implementation (v1), retraining is external to Torus:

1. Threshold reached / end of semester  
2. DataShop export generated (or Torus native data queried directly)  
3. Offline training script runs  
4. New parameters computed (β\_kc, β\_item, regression coefficients)  
5. Parameters uploaded as unpublished revision  
6. Author reviews and publishes before next semester

Building retraining directly into Torus requires a training pipeline, job scheduling, and parameter storage infrastructure, out of scope for v35. External retraining keeps the engineering footprint small while delivering the model.  
Note: Future iteration: a built-in Torus retraining button in Authoring that triggers retraining and automatically uploads parameters as an unpublished revision.

## **5.2 Alternative Architecture: Torus Native Data**

The empirical comparison used DataShop export format as a standard research format. For production deployment, training directly on Torus native data is a cleaner approach. sub-objective and activity IDs are native Torus IDs throughout, eliminating the KC/activity ID mapping problem that arises when using DataShop exports across duplicated course packages.

Note: When a course package is duplicated to create a new semester, Torus generates new internal IDs. Parameters trained on prior semester DataShop data are keyed to prior semester IDs and cannot be directly transferred. Training on Torus native data sidesteps this problem entirely.

## **5.3 Retraining Cadence: Threshold-Triggered**

Rather than a fixed calendar schedule, retraining is triggered by data accumulation thresholds:

* Item difficulty (β\_item) \- retrain when enough new unique students have crossed the max(10, 30%) threshold since the last run  
* KC difficulty (β\_kc) \- retrain when sufficient new student cohort data has accumulated  
* Minimum interval \- no more frequently than weekly  
* Maximum interval \- at least once per semester regardless of threshold status  
* Recency logit \- real time, no retraining needed

In practice: a weekly check determines whether thresholds have been crossed and retraining is warranted. End of semester forces a retrain regardless.

## **5.4 Parameter Versioning: Publication Model**

Parameter updates conform to the existing Torus publication workflow:

* New parameters are uploaded as unpublished revisions \- identical to content edits in Authoring  
* Active sections continue on current parameters until the author publishes the update  
* Author reviews parameters before publishing, prevents unexpected mid-semester changes  
* Once published, updated parameters apply to all new sections  
* Existing active sections remain on prior parameters until their next publication cycle

This approach is consistent with existing Torus authoring behavior, prevents mid-semester disruption, and provides an audit trail of when parameters changed and who published them.

# **6\. Learning Objective Aggregation**

## **6.1 Sub-Objective Score**

The sub-objective score is the LKT-AOA estimate for a given student on a given sub-objective  \- the arithmetic mean of all LKT P(correct) predictions across all attempts:

sub\_objective\_score(s,k) \= (1/n) × Σ P(correct)ᵢ

s \= student, k \= sub-objective, n \= attempts by s on k

Range: 0 to 1\. Higher values indicate higher estimated proficiency. Updated after each new attempt.

## **6.2 LO-Level Aggregation**

Sub-objective scores aggregate to the LO level using a weighted average, weighted by number of tagged opportunities per sub-objective:

LO\_score \= Σ(sub\_objective\_score × opportunities) / Σ opportunities

Weighting by opportunities is justified by the signal-to-noise principle \- sub-objectives with more student attempts produce more reliable estimates and should contribute proportionally more to the LO-level score. This follows compensatory aggregation principles from IRT-based assessment frameworks.

## **6.3 Coverage Gaps**

All sub-objectives contribute to the LO-level weighted average regardless of attempt count; sub-objectives with fewer attempts receive lower weight proportional to their unique activity count, but are not excluded. This prevents artificially suppressing LO scores when some sub-objectives have low data.

Example: Parent LO with two sub-objectives, SUB1 has 100 attempts (score 0.75) and SUB2 has 1 attempt (score 0.5). SUB1 receives much higher weight in the LO average because more unique activities were attempted. SUB2 still contributes but minimally. The LO displays its weighted average score alongside a coverage gap indicator flagging that SUB2 has insufficient data for a reliable estimate.

Coverage gap indicators are surfaced at the LO level, showing which sub-objectives have low attempt counts, without suppressing the overall LO score. This allows instructors to see both the aggregate picture and where data is thin.

Note: UX support needed from Jess to design the coverage gap indicator display at the LO level.

## 

## **6.4 Tagging Hierarchy: Double-Counting Prevention**

Each student attempt counts toward the most specific tag only:

* Tagged to sub-objective only → counts to sub-objective, never to parent LO directly  
* Tagged to LO only (no sub-objective tag) → counts to LO level only  
* Tagged to both LO and sub-objective → counts to sub-objective only

The LO score is always derived from sub-objective rollup \- never from direct LO-level attempt counts. This rule needs to be enforced at the platform level. Authors should be guided to tag at the sub-objective level. Activities tagged only at the LO level will be orphaned from the sub-objective rollup and may create coverage gaps.

**Transition Rule:  New vs Existing Courses**

* **New courses:** restrict activity tagging to sub-objectives only. Authors are guided to tag at the sub-objective level, not the parent LO level. A Jira ticket has been filed to enforce this constraint for new course packages.

* **Existing courses:** preserve existing mixed LO/sub-objective tagging approaches. Existing courses will not be retroactively remapped \- they continue to function under the current mixed model.

Notes: 

1. Item difficulty coefficients can be carried over when duplicating course packages \- this resolves the ID mapping concern raised during engineering review. Darren confirmed this is feasible for v35.  
2. The prevalence of double-tagging in OLI/Torus courses is unknown pending input from Jess. This will determine whether double-counting prevention requires engineering effort now or can be deferred. 

## **6.5 Display Thresholds**

Display thresholds are consistent with the current model, applied to the weighted average LKT-AOA score:

* High: \> 80%  
* Medium: 40–80%  
* Low: \< 40%  
* Not enough information: fewer than 3 attempts on one or more sub-objectives

# **7\. Confidence Metric & Privacy Controls**

LKT-AOA outputs a point estimate without a native uncertainty measure. Confidence is reported at two distinct levels.

## **7.1 Student-Level Confidence**

Proficiency and confidence are intentionally separate signals:

* Proficiency (LKT-AOA) answers: what does the model predict about the student's knowledge? It uses all attempts including repeated ones, with recency weighting \- every interaction updates the estimate.  
* Confidence answers: how much should we trust that proficiency estimate? It uses the count of unique activities attempted, breadth of evidence, not depth.

Why unique activities for confidence: a student who answered the same question 10 times has not demonstrated the same breadth of knowledge as a student who answered 10 different questions, even if their total attempt count is identical. Confidence reflects how many distinct activities the student has encountered on a sub-objective, not how many total attempts they have made. This is intentionally separate from the proficiency calculation, which already accounts for all attempts through the recency logit and opportunity count.

Primary Signal: count of unique activities attempted on that sub-objective, modeled with a diminishing returns function. Each additional unique activity attempted increases confidence, but with diminishing marginal returns, the jump from 0 to 1 unique activity matters more than the jump from 9 to 10\. 

*   
* Optional pages: activities on optional pages that students choose not to engage with do not penalize confidence.  
* Repeated attempts on the same activity: counted once toward unique activity count regardless of how many times the student has attempted it.

The diminishing returns function means confidence grows quickly with early unique activities and plateaus as more are added. Exact function parameters will be calibrated empirically on OLI data 

### **Evidence Quantity**

Evidence Quantity measures how much valid learner evidence supports the proficiency estimate.

Confidence should increase rapidly during the learner's first several interactions and gradually level off as additional evidence provides diminishing returns.

The Evidence Quantity score is calculated as:

Qn=1−e−n/kQ\_n \= 1 \- e^{-n/k}Qn​=1−e−n/k

where:

* nnn is the number of valid evidence events contributing to the proficiency estimate.  
* kkk is a configurable saturation constant controlling how quickly confidence approaches its maximum.

This function ensures that the first few observations substantially increase confidence while preventing unlimited growth as evidence accumulates.

## **7.2 Section-Level Confidence & Data Suppression**

Reflects certainty in the class-wide proficiency picture on instructor dashboards.

Confidence is aggregated across all students in the section, not suppressed based on enrollment thresholds. The section-level confidence signal is the aggregate of individual student confidence scores (unique activities attempted with diminishing returns), averaged across all students who have attempted activities on that sub-objective.

* Always display "Based on X of Y students" alongside the aggregate so instructors know how many students the estimate is based on.  
* No hard enrollment threshold is applied, instructors in small sections still see proficiency data, with confidence reflecting the limited sample size.

Note: The previous 50% enrollment threshold and N\<5 hard suppression have been removed following discussion with Darren and Laura. Hard suppression thresholds risk leaving instructors with zero proficiency data for entire semesters, particularly in small or adaptive courses. FERPA compliance is addressed through anonymization of individual student data, not aggregate suppression.

# **8\. Cold Start Behavior**

## **8.1 New Students**

Recency logit initializes at 0 (neutral) and updates after the first attempt. KC and item intercepts from prior semesters apply immediately, so the model makes reasonable predictions from the first attempt.

## **8.2 New Courses**

All datasets in the empirical comparison had sufficient historical data \- the cold start scenario did not arise in the experiments. For a brand new course with no prior data, KC and item intercepts default to 0\. In this state, LKT operates on opportunity count and recency logit only, behaving similarly to a PFA-style model with log-compressed opportunity scaling and exponentially weighted history. Full parameterization becomes available after the first semester.

Note: The cold start fallback does not affect the validity of the experimental results. All tested datasets had sufficient prior data.

## **8.3 New Items**

Items added mid-semester default to β\_item \= 0 until the threshold is crossed. Empirical Bayes shrinkage, starting from β\_kc as a prior and migrating toward the empirical mean, is planned as a more principled alternative.

# **9\. Limitations and Next Steps** 

1. **Recency decay is attempt-based, not time-based:** The recency logit decays by attempt count (0.9 per attempt) rather than elapsed calendar time. A student returning after two weeks is treated identically to one returning after five minutes. Forgetting is time-dependent \- ACT-R memory models and spaced practice research are clear on this. Adding a time-elapsed decay term (Δt) is planned for a future iteration.  
2. **Compare Full-sequence AOA with exponentially or windowed AOA:** Because opportunity count and recency logit increase with practice, early low P(correct) predictions might drag down the lifetime AOA average. Will need to compare full-sequence AOA with exponentially weighted AOA and windowed AOA.   
3. **Validation against post-test data:** Next-step validation is used currently, AUC and RMSE against next-step correctness on held-out students. Baker et al. (2023) showed that within-system metrics are necessary but not sufficient. The next step is validating whether knowledge estimates predict performance on OLI checkpoints and post-tests.  
4. **Hint usage features:** Raw hint count adds minimal predictive value. Hint-seeking behavior in ITS research is bimodal , strategic use (meta-cognitive, gap-bridging) vs. gaming (clicking through to the answer), and a raw count conflates both. More informative features being explored include latency-to-hint, hint depth, hint ratio, and post-hint correctness. Planned for a future iteration.   
5. **Student ability parameter (iLKT):** Prior work on REAL Chemistry showed that adding a global student ability parameter (θs​, like IRT) on top of an LKT-style model recovers most of the remaining gap between logistic regression and the ML ceiling.   
6. **Calibrate confidence metric thresholds empirically on OLI data**

# **10\. Open Questions for Engineering and Product  (Darren & Laura)**

1. What is the latency requirement for P(correct) predictions, per attempt in real time, or batched per session?

2. Should parameter updates require a separate permission level from content edits? A learning engineer or platform admin may be better positioned to review and publish parameter changes than a course author.

3. (Resolved) When a course package is duplicated to create a new semester, Torus generates new internal IDs for all sub-objectives and activities. Parameters trained on prior semester data are keyed to prior semester IDs. How should parameter transfer work across duplicated packages? (Options: content hash matching (title \+ content fingerprint), canonical base package approach (parameters on base, not duplicate), or name-based matching (fragile if authors rename).)

   * Resolved: item difficulty coefficients can be carried over when duplicating course packages- Darren confirmed this is feasible for v35. The ID mapping problem does not block the initial implementation.

4. How will the model handle new items added mid-semester with no learned difficulty estimate?

5. Can there be a mechanism to flag items still at β\_item \= 0 so authors know which items lack learned difficulty parameters?

   * Items still at β\_item \= 0 will be flagged to authors so they know which items lack learned difficulty parameters.

6. For internal retraining (future): what is the preferred trigger \- author-initiated button, scheduled job, or threshold-based automatic trigger?

*Tanvi Domadia | Senior Learning Engineer | CMU Open Learning Initiative | July 2026*

