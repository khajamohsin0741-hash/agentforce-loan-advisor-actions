/**
 * Agentforce agent action (also usable from Flow): summarizes a loan application and
 * returns rule-based next best actions for the advisor.
 *
 * Security: runs with sharing and queries in user mode, so the agent can only see loans
 * the running user can see. The output never includes account numbers or tax IDs.
 */
public with sharing class LoanSummaryAction {
    public class Request {
        @InvocableVariable(
            required=true
            label='Loan Application Id'
            description='Salesforce record Id of the Loan Application to summarize'
        )
        public Id loanApplicationId;
    }

    public class Result {
        @InvocableVariable(label='Summary' description='One-paragraph plain-language status of the application')
        public String summary;
        @InvocableVariable(label='Recommended Actions' description='Ordered list of next best actions for the advisor')
        public List<String> recommendedActions;
        @InvocableVariable(label='Error Message' description='Set when the application cannot be found or accessed')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Summarize Loan Application'
        description='Returns a status summary and next best actions for one loan application. Use when an advisor asks about the status, risks or next steps of a specific loan application.'
        category='Loan Advisor'
    )
    public static List<Result> summarize(List<Request> requests) {
        Set<Id> ids = new Set<Id>();
        for (Request req : requests) {
            ids.add(req.loanApplicationId);
        }
        Map<Id, Loan_Application__c> loans = new Map<Id, Loan_Application__c>(
            [
                SELECT
                    Id, Name, Account__r.Name, Product__c, Stage__c, Stage_Entered__c, Requested_Amount__c,
                    Credit_Score_Band__c, Debt_To_Income__c, Missing_Documents__c
                FROM Loan_Application__c
                WHERE Id IN :ids
                WITH USER_MODE
            ]
        );

        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            Loan_Application__c loan = loans.get(req.loanApplicationId);
            if (loan == null) {
                res.errorMessage = 'Loan application not found, or you do not have access to it.';
                res.recommendedActions = new List<String>();
            } else {
                LoanNextBestActionRules.Facts facts = toFacts(loan, Date.today());
                res.summary = buildSummary(loan, facts);
                res.recommendedActions = LoanNextBestActionRules.recommend(facts);
            }
            results.add(res);
        }
        return results;
    }

    @TestVisible
    private static LoanNextBestActionRules.Facts toFacts(Loan_Application__c loan, Date today) {
        LoanNextBestActionRules.Facts facts = new LoanNextBestActionRules.Facts();
        facts.stage = loan.Stage__c;
        facts.debtToIncome = loan.Debt_To_Income__c;
        facts.creditBand = loan.Credit_Score_Band__c;
        facts.missingDocuments = LoanNextBestActionRules.parseDocuments(loan.Missing_Documents__c);
        facts.daysInStage = loan.Stage_Entered__c == null ? null : loan.Stage_Entered__c.daysBetween(today);
        return facts;
    }

    @TestVisible
    private static String buildSummary(Loan_Application__c loan, LoanNextBestActionRules.Facts facts) {
        List<String> parts = new List<String>();
        String borrower = loan.Account__r == null ? 'an unnamed borrower' : loan.Account__r.Name;
        String amount = loan.Requested_Amount__c == null
            ? 'an unspecified amount'
            : '$' + loan.Requested_Amount__c.setScale(2).format();
        parts.add(
            loan.Name + ' for ' + borrower + ': ' + (loan.Product__c == null ? 'loan' : loan.Product__c + ' loan') +
            ' of ' + amount + '.'
        );
        if (loan.Stage__c != null) {
            parts.add(
                'Stage: ' + loan.Stage__c + (facts.daysInStage == null ? '.' : ' for ' + facts.daysInStage + ' days.')
            );
        }
        if (loan.Credit_Score_Band__c != null) {
            parts.add('Credit band ' + loan.Credit_Score_Band__c + '.');
        }
        if (loan.Debt_To_Income__c != null) {
            parts.add('Debt-to-income ' + loan.Debt_To_Income__c.setScale(1) + '%.');
        }
        parts.add(
            facts.missingDocuments.isEmpty()
                ? 'No documents outstanding.'
                : facts.missingDocuments.size() + ' document(s) outstanding.'
        );
        return String.join(parts, ' ');
    }
}
