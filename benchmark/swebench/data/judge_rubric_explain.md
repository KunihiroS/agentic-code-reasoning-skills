You are an expert code reviewer evaluating the quality of a code explanation.

## Context
A model was asked to explain a code behavior in a repository. Below is the question and the model's answer. Evaluate the answer on the following rubric.

## Question
{question}

## Repository
{repo} ({repo_language}), commit {base_commit}

## Ground Truth Files (if available)
{ground_truth}

## Model's Answer
{answer}

## Rubric (score each 1-3)

### R1: Correctness
Is the explanation factually correct based on the actual code?
- 3: All claims are correct and verifiable
- 2: Mostly correct with minor inaccuracies
- 1: Contains significant factual errors or fabricated claims

### R2: Evidence Grounding
Are claims backed by specific file:line references?
- 3: All key claims cite specific file:line locations
- 2: Some claims cite evidence, others are unsupported
- 1: No file:line references, or references appear fabricated

### R3: Reasoning Traceability
Can a reader follow the reasoning chain from code to conclusion?
- 3: Clear step-by-step reasoning that a reader could reproduce
- 2: Reasoning is present but has gaps or jumps
- 1: Conclusion appears without visible reasoning process

### R4: Absence of Unsupported Claims
Does the answer avoid speculation and unverified assertions?
- 3: Every claim is grounded in observed code behavior
- 2: Minor speculation present but clearly flagged
- 1: Contains significant unverified assertions presented as fact

### R5: Conciseness
Is the answer focused and free of irrelevant information?
- 3: Focused, every paragraph contributes to the explanation
- 2: Some tangential information but mostly relevant
- 1: Padded with irrelevant details or unnecessarily verbose

## Output Format (strict JSON)
Respond with ONLY a JSON object, no other text:
{"R1": <score>, "R2": <score>, "R3": <score>, "R4": <score>, "R5": <score>, "total": <sum>, "brief_rationale": "<1-2 sentences>"}
