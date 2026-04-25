You are performing a security audit of a software repository.

## Task
Given a bug report describing a security issue and the repository state at a specific commit, identify the **file(s) and function(s)** that contain the security vulnerability. Do NOT write a fix — only identify where the vulnerable code is.

## Bug Report (Problem Statement)
{problem_statement}

## Repository Information
- Repository: {repo}
- Language: {repo_language}
- Base commit: {base_commit}

## Failing Tests
These tests currently FAIL and should PASS after the vulnerability is fixed:
{fail_to_pass}

## Instructions
1. Read the bug report carefully to understand the security issue described.
2. Examine the failing test(s) to understand what security property they check.
3. Trace from the failing test(s) backward through the code to find the vulnerable code.
4. Identify the specific file(s) and function(s)/method(s) where the vulnerability exists.

## Required Output
End your analysis with a structured verdict on the LAST lines:

LOCALIZATION:
FILE: <file_path>
FUNCTION: <function_or_method_name>

If multiple files/functions are involved, list each on a separate FILE:/FUNCTION: line.
