# Public Download Verification

`OuroborosChatGPT.manifest.json` is the public download manifest for
`OuroborosChatGPT.exe`.

Required fields:

- `availability`: `disabled` or `enabled`.
- `file`: file name under `downloads/`.
- `sha256`: lowercase SHA-256 hash of the file bytes.
- `production`: `true` only for a release candidate that must pass Windows
  Authenticode verification.
- `expectedSignerSubject`: exact certificate subject expected for production
  releases, unless the repository variable `EXPECTED_SIGNER_SUBJECT` is set.

Verification:

- `node scripts/check-download-metadata.mjs` validates manifest shape, rejects
  zero or placeholder signer values, and checks that `sha256` matches the EXE.
- `.github/workflows/verify-public-download.yml` runs on Windows and fails
  production verification unless Authenticode status is `Valid`, a timestamp
  certificate is present, and the signer subject exactly matches the configured
  expected signer.

The metadata check also rejects unmanifested `.exe` files and requires
`index.html` to link exactly once to the manifested executable. A publicly
linked executable cannot use `production: false`.

The `disabled` state is the only allowed exception: it requires null file,
hash, and signer fields, `production: false`, no `.exe` under `downloads/`, and
no executable link in `index.html`. Promotion changes the state to `enabled`
only when the signed installer and production manifest arrive together.

GitHub Pages must use the Actions deployment source. The deploy job depends on
both metadata and Windows Authenticode verification; legacy branch deployment
would bypass this contract. Protect `main` with required checks for `Metadata
and hash check` and `Windows Authenticode release gate`, and require CODEOWNERS
review for workflow, script, download, and link changes.

The download remains disabled until it is replaced by a signed promotion
artifact.
