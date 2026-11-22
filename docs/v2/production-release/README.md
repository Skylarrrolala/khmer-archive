# V2 production release

Application source: reviewed candidate `14334f8915cbae0e8eae8a4ca847727bbb81b423`, including the Next.js 16.4.6 security patch and SQL safeguards. The production release is a clean commit on existing main.

The owner approved seven Wikimedia Commons replacements. Their file-page authors, licences, source links and modifications are recorded in `photo-credits.json` and displayed by the application. The Num Kong photograph is identified as a mixed tray; the Num Bot photograph is identified as filling whose source ingredients differ from the record. The Chek photograph is cropped to exclude the printed sign. Kroch's current photograph is withheld pending reuse permission, without changing its database row or Storage object.

No content update, migration, account creation or database write is part of this release. It runs against the existing production migrations 0001–0008 and existing production environment variables. The seven-row content update remains a separate, unapplied operation. Preview guards, QA imagery and preview-specific configuration are excluded.

Verification: unit tests, lint, TypeScript, production build, dependency audit, disposable database/RLS tests and SQL refusal tests. Production browsing checks are read-only. Authenticated review decisions must not be exercised against production as a deployment test.
