# git-crypt and pass 2 (encrypted-secret integrity)

Load this in Step 1, item 2, when the project's secret-management scheme is git-crypt.

git-crypt files are binary-looking in the working tree, but that's enforced by git
attributes, not grep. For git-crypt there is usually nothing meaningful to grep-check, so
skip pass 2 for it: leave `<ENCRYPTED_GLOB>` and `<ENCRYPTED_MARKERS>` empty, the same as
for a project with no scheme, and the generated script prints its pass-2 skip line.
