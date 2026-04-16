# SWE-bench Patch Equivalence Benchmark Report

**Runs directory:** `benchmark/swebench/runs/iter-5`


## without_skill

| Metric | Value |
|---|---|
| Overall Accuracy | 16/20 = 80.0% |
| EQUIV Accuracy | 6/10 = 60.0% |
| NOT_EQUIV Accuracy | 10/10 = 100.0% |
| Total Cost | $2.70 |
| Avg Turns | 8.0 |

## with_skill

| Metric | Value |
|---|---|
| Overall Accuracy | 17/20 = 85.0% |
| EQUIV Accuracy | 7/10 = 70.0% |
| NOT_EQUIV Accuracy | 10/10 = 100.0% |
| Total Cost | $2.95 |
| Avg Turns | 8.7 |

## Comparison

| | without_skill | with_skill | Delta |
|---|---|---|---|
| Accuracy | 80.0% | 85.0% | +5.0% |

## Per-Instance Results

| Instance | GT | without_skill | with_skill |
|---|---|---|---|
| django__django-10999 | NEQ | ✓ | ✓ |
| django__django-11179 | EQ | ✓ | ✓ |
| django__django-11433 | NEQ | ✓ | ✓ |
| django__django-11603 | NEQ | ✓ | ✓ |
| django__django-11999 | NEQ | ✓ | ✓ |
| django__django-12262 | NEQ | ✓ | ✓ |
| django__django-12276 | EQ | ✓ | ✓ |
| django__django-12663 | NEQ | ✓ | ✓ |
| django__django-13417 | NEQ | ✓ | ✓ |
| django__django-13821 | EQ | ✗ UNKNOWN | ✗ NO |
| django__django-14089 | EQ | ✓ | ✓ |
| django__django-14122 | NEQ | ✓ | ✓ |
| django__django-14311 | NEQ | ✓ | ✓ |
| django__django-14373 | EQ | ✗ NO | ✓ |
| django__django-14672 | EQ | ✓ | ✓ |
| django__django-14765 | EQ | ✓ | ✓ |
| django__django-14787 | NEQ | ✓ | ✓ |
| django__django-15315 | EQ | ✓ | ✓ |
| django__django-15368 | EQ | ✗ NO | ✗ NO |
| django__django-15382 | EQ | ✗ NO | ✗ NO |
