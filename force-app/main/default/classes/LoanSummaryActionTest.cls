@IsTest
private class LoanSummaryActionTest {
    private static LoanSummaryAction.Request request(Id loanId) {
        LoanSummaryAction.Request req = new LoanSummaryAction.Request();
        req.loanApplicationId = loanId;
        return req;
    }

    @IsTest
    static void summarizesAccessibleLoan() {
        User u = LoanTestData.advisor();
        Account borrower = new Account(Name = 'Maple Street Bakery (synthetic)', OwnerId = u.Id);
        insert borrower;
        Loan_Application__c loan = new Loan_Application__c(
            Account__c = borrower.Id,
            OwnerId = u.Id,
            Product__c = 'Small Business',
            Stage__c = 'Underwriting',
            Stage_Entered__c = Date.today().addDays(-12),
            Requested_Amount__c = 250000,
            Credit_Score_Band__c = 'B',
            Debt_To_Income__c = 38,
            Missing_Documents__c = 'Bank statements'
        );
        insert loan;

        List<LoanSummaryAction.Result> results;
        System.runAs(u) {
            Test.startTest();
            results = LoanSummaryAction.summarize(new List<LoanSummaryAction.Request>{ request(loan.Id) });
            Test.stopTest();
        }

        LoanSummaryAction.Result res = results[0];
        Assert.isNull(res.errorMessage);
        Assert.isTrue(res.summary.contains('Maple Street Bakery (synthetic)'), res.summary);
        Assert.isTrue(res.summary.contains('Small Business loan'), res.summary);
        Assert.isTrue(res.summary.contains('Underwriting for 12 days'), res.summary);
        Assert.isTrue(res.summary.contains('1 document(s) outstanding'), res.summary);
        Assert.areEqual(2, res.recommendedActions.size(), String.valueOf(res.recommendedActions));
        Assert.isTrue(res.recommendedActions[0].contains('Bank statements'));
        Assert.isTrue(res.recommendedActions[1].contains('Escalate'));
    }

    @IsTest
    static void returnsErrorForMissingOrHiddenRecord() {
        User u = LoanTestData.advisor();
        // A deleted record exercises the same not-found path as a record hidden by sharing.
        Loan_Application__c loan = new Loan_Application__c(Stage__c = 'Intake');
        insert loan;
        Id loanId = loan.Id;
        delete loan;

        List<LoanSummaryAction.Result> results;
        System.runAs(u) {
            results = LoanSummaryAction.summarize(new List<LoanSummaryAction.Request>{ request(loanId) });
        }
        Assert.areEqual('Loan application not found, or you do not have access to it.', results[0].errorMessage);
        Assert.isNull(results[0].summary);
        Assert.areEqual(0, results[0].recommendedActions.size());
    }

    @IsTest
    static void summaryHandlesSparseRecord() {
        // Name is an auto-number (read-only), so build the in-memory record from JSON.
        Loan_Application__c loan = (Loan_Application__c) JSON.deserialize('{"Name":"LA-00099"}', Loan_Application__c.class);
        LoanNextBestActionRules.Facts facts = LoanSummaryAction.toFacts(loan, Date.today());
        String summary = LoanSummaryAction.buildSummary(loan, facts);
        Assert.areEqual('LA-00099 for an unnamed borrower: loan of an unspecified amount. No documents outstanding.', summary);
    }
}
