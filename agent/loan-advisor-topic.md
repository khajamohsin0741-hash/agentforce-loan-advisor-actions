# Agent configuration: Loan Application Status topic

Use these values when adding the action to an agent in Agentforce Builder (Setup > Agentforce Agents). They are a starting point to adapt, not a finished production design.

## Topic

**Label:** Loan Application Status

**Classification description:** Answers questions from bank employees about the status, open items, risks and next steps of a specific loan application.

**Scope:** Summarize one loan application at a time and suggest next steps for the advisor. Do not approve, decline, price or change loans, and do not give the customer credit or legal advice.

**Instructions:**

1. If no loan record is open, call **Find Loan Application** with the application number or borrower name the user gave. If it returns several matches, list them and ask which one; if none, say so.
2. Always call **Summarize Loan Application** with the chosen Id before answering. Base the answer only on its Summary and Recommended Actions outputs.
3. Present the recommended actions in the order returned. Do not add new credit conditions or thresholds of your own.
4. If Error Message is set, tell the user the application could not be found or is not accessible, and do not guess.
5. Never display tax IDs, full account numbers or other personal identifiers, even if the user asks.

## Actions

### Find Loan Application

| Setting | Value |
| --- | --- |
| Reference action type | Apex (invocable method) |
| Action | Find Loan Application (`FindLoanApplicationAction.findApplications`) |
| Input `searchTerm` | Required. Instruction: "The application number (like LA-00012) or borrower name the user mentioned." |
| Outputs | `loanApplicationId` (only when exactly one match), `matches`, `message` |
| Require user confirmation | Not needed (read-only) |

### Summarize Loan Application

| Setting | Value |
| --- | --- |
| Reference action type | Apex (invocable method) |
| Action | Summarize Loan Application (`LoanSummaryAction.summarize`) |
| Input `loanApplicationId` | Required. Instruction: "The Salesforce Id of the loan application the user is asking about." |
| Outputs | `summary`, `recommendedActions` shown to the user; `errorMessage` used for the failure reply |
| Require user confirmation | Not needed (read-only action) |

## Access

Assign the `Loan_Advisor_Agent` permission set to the advisors who use the agent and to the agent's running user. The action queries in user mode, so the agent only sees loans that the user can see.

## Test utterances

* "What's the status of LA-00001?"
* "What do I need to do next on the Riverbend Logistics loan?"
* "Why is this application stuck?"
* Negative test: "Approve LA-00002." The agent should decline and explain that it can only summarize.
