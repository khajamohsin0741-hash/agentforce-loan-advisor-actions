@IsTest
private class FindLoanApplicationActionTest {
    private static FindLoanApplicationAction.Request request(String term) {
        FindLoanApplicationAction.Request req = new FindLoanApplicationAction.Request();
        req.searchTerm = term;
        return req;
    }

    @IsTest
    static void findsSingleApplicationByBorrowerName() {
        User u = LoanTestData.advisor();
        Account bakery = new Account(Name = 'Maple Street Bakery (synthetic)', OwnerId = u.Id);
        Account logistics = new Account(Name = 'Riverbend Logistics (synthetic)', OwnerId = u.Id);
        insert new List<Account>{ bakery, logistics };
        Loan_Application__c bakeryLoan = LoanTestData.loan(bakery.Id, u.Id, 'Underwriting');
        insert new List<Loan_Application__c>{ bakeryLoan, LoanTestData.loan(logistics.Id, u.Id, 'Intake') };

        List<FindLoanApplicationAction.Result> results;
        System.runAs(u) {
            Test.startTest();
            results = FindLoanApplicationAction.findApplications(new List<FindLoanApplicationAction.Request>{ request('maple street') });
            Test.stopTest();
        }

        Assert.areEqual(bakeryLoan.Id, results[0].loanApplicationId);
        Assert.areEqual(1, results[0].matches.size());
        Assert.isTrue(results[0].matches[0].endsWith('Maple Street Bakery (synthetic) · Underwriting'), results[0].matches[0]);
    }

    @IsTest
    static void findsByApplicationNumber() {
        User u = LoanTestData.advisor();
        Loan_Application__c loan = LoanTestData.loan(null, u.Id, 'Approved');
        insert loan;
        String appNumber = [SELECT Name FROM Loan_Application__c WHERE Id = :loan.Id].Name;

        List<FindLoanApplicationAction.Result> results;
        System.runAs(u) {
            results = FindLoanApplicationAction.findApplications(new List<FindLoanApplicationAction.Request>{ request(appNumber) });
        }
        Assert.areEqual(loan.Id, results[0].loanApplicationId);
        Assert.isTrue(results[0].matches[0].contains('No borrower'));
    }

    @IsTest
    static void multipleMatchesAskTheUserToChoose() {
        User u = LoanTestData.advisor();
        Account acc = new Account(Name = 'Harbor Freight Imports (synthetic)', OwnerId = u.Id);
        insert acc;
        insert new List<Loan_Application__c>{ LoanTestData.loan(acc.Id, u.Id, 'Intake'), LoanTestData.loan(acc.Id, u.Id, 'Funded') };

        FindLoanApplicationAction.Result res;
        System.runAs(u) {
            res = FindLoanApplicationAction.findOne('Harbor Freight');
        }
        Assert.isNull(res.loanApplicationId);
        Assert.areEqual(2, res.matches.size());
        Assert.isTrue(res.message.startsWith('2 applications match'), res.message);
    }

    @IsTest
    static void capsMatchesAtFive() {
        User u = LoanTestData.advisor();
        Account acc = new Account(Name = 'Northgate Advisory (synthetic)', OwnerId = u.Id);
        insert acc;
        List<Loan_Application__c> loans = new List<Loan_Application__c>();
        for (Integer i = 0; i < 7; i++) {
            loans.add(LoanTestData.loan(acc.Id, u.Id, 'Intake'));
        }
        insert loans;

        FindLoanApplicationAction.Result res;
        System.runAs(u) {
            res = FindLoanApplicationAction.findOne('Northgate');
        }
        Assert.areEqual(FindLoanApplicationAction.MAX_MATCHES, res.matches.size());
        Assert.isTrue(res.message.startsWith('More than 5'), res.message);
    }

    @IsTest
    static void shortOrMissingTermIsRejectedWithoutQuery() {
        Integer before = Limits.getQueries();
        Assert.isTrue(FindLoanApplicationAction.findOne('ab').message.startsWith('Enter at least 3'));
        Assert.isTrue(FindLoanApplicationAction.findOne(null).message.startsWith('Enter at least 3'));
        Assert.areEqual(before, Limits.getQueries());
    }

    @IsTest
    static void noMatchReturnsHelpfulMessage() {
        User u = LoanTestData.advisor();
        FindLoanApplicationAction.Result res;
        System.runAs(u) {
            res = FindLoanApplicationAction.findOne('Nonexistent Borrower');
        }
        Assert.isNull(res.loanApplicationId);
        Assert.isTrue(res.message.startsWith('No loan application matches'), res.message);
    }

    @IsTest
    static void wildcardsInInputAreMatchedLiterally() {
        Assert.areEqual('100\\%', FindLoanApplicationAction.escapeLike('100%'));
        Assert.areEqual('a\\_b', FindLoanApplicationAction.escapeLike('a_b'));
        Assert.areEqual('c\\\\d', FindLoanApplicationAction.escapeLike('c\\d'));
    }
}
