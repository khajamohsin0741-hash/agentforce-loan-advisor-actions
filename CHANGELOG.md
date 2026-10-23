# Changelog

## 1.1.0 - 2026-10-23

- Added **Find Loan Application** agent action: search by application number or borrower name, with LIKE wildcard escaping and a five-match cap.
- Moved rule thresholds (debt-to-income guideline, underwriting target days) to the `Loan_Rule_Setting__mdt` custom metadata type with code fallbacks.
- Added shared `LoanTestData` factory, Dependabot and a security policy.

## 1.0.0 - 2026-10-23

- Summarize Loan Application agent action, deterministic next-best-action rules, permission set, agent topic guide, sample data and CI.
