# 13001 API acceptance and CHI fix — 2026-10-19

## Scope and result
Local Docker Kong/Adapter -> NocoBase 119.91.104.211:13001/cmtf2.
Twelve retained business families completed Create and Update with successful staging, dispatcher/child executions and selected-field readback: NLA, CHI, LRN, AIP, Self-withdraw, Specific Hour, RP, Home Manager, Beds/Layout, Operation Mode, Nurse-in-Charge and Directors.
Prosecution is retired; its public Adapter/Kong routes are removed. Revoke was outside this acceptance scope.
Admin credentials were used: OP least-privilege acceptance remains outstanding. Word v0.8.1 and implemented fields still differ; this is not exhaustive specification compliance.

## CHI correction
Omitting part_5/checklist was accepted by the API but mapped to null by the workflow, causing chi_checklist_must_be_an_array. Read checklist presence from the original staged request body instead of the mapped value. Omission is allowed; explicit null/non-array values, duplicate positions and more than 100 entries remain rejected.
The generator now supplies stagedBody = {{$context.data.f_request_body}} to both validation nodes. The validation script matches the tested 13001 revision.

13001 workflow key: 6mde7gtz5kx.
Old revision: 392932735188992 (disabled, retained).
Active revision: 392971884822528.
Only the Create/Update checklist validation nodes changed. Dispatcher calls the workflow by key and was not modified.

Runtime regression: with and without attachments, Create and Update succeeded with field readback and successful dispatcher/child executions. Twelve local guard checks passed.
No-checklist Create staging: 392971947737088; Update: 392971968708608.
With-checklist Create staging: 392972050497536; Update: 392972383944704.

## User-managed migration to 13000
The user owns migration; no 13000 changes were performed.
Export/back up the target workflow first. Use the target environment's workflow key and IDs, not the 13001 numeric IDs above. For an already executed workflow, create an editable revision via the supported NocoBase revision operation. Preserve its key so the dispatcher resolves the new version. Apply only the two validation-node changes (script plus stagedBody argument); verify the candidate before enabling it. Retain the prior version disabled for rollback. Do not blindly run legacy broad workflow-upgrade scripts against the unified child.
After migration, repeat CHI Create/Update with omitted checklist and with a valid uploaded attachment. Check staging, parent/child executions and query readback. Also verify explicit null, invalid arrays, duplicate positions and oversized input remain rejected. Roll back by disabling the new revision and enabling the previous revision under the same key.

## Remaining limitations
Intermittent upstream ConnectError/timeouts and a transient AIP query 502 were observed. AIP passed a new complete test; network reliability is not fixed by this workflow patch.
211-hosted Kong/Adapter image and upstream configuration were not verified as identical to local Docker. 13000, load/concurrency and long-duration stability were not accepted.
No delivery archive was generated. Test records/attachments remain in 13001. Credentials, full workflow dumps and payloads are intentionally excluded from Git.

## Local evidence
C:/CMTF-II/kong-nocoadapter-artifacts/matrix-20261019/final-matrix.json
C:/CMTF-II/kong-nocoadapter-artifacts/workflow-fix-20261019/
These paths are local evidence, not downloadable repository artifacts.

Source commit: 4b2068a993e688b7ec51ed8e6bd6c04a329205c7 (kong-nocoadapter main).
Commit validation: 69 targeted tests passed using Python UTF-8 mode on Windows.
