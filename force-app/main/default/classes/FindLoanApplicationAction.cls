/**
 * Agentforce agent action: finds a loan application by application number (for example
 * LA-00012) or borrower name, so the user does not need to know the record Id.
 * The planner can then pass the returned Id to "Summarize Loan Application".
 *
 * Security: with sharing + USER_MODE query, bind variables (no dynamic SOQL), and LIKE
 * wildcards in user input are escaped.
 */
public with sharing class FindLoanApplicationAction {
    public static final Integer MAX_MATCHES = 5;
    public static final Integer MIN_SEARCH_LENGTH = 3;

    public class Request {
        @InvocableVariable(
            required=true
            label='Search Term'
            description='Loan application number (for example LA-00012) or part of the borrower name'
        )
        public String searchTerm;
    }

    public class Result {
        @InvocableVariable(label='Loan Application Id' description='Set only when exactly one application matches')
        public Id loanApplicationId;
        @InvocableVariable(label='Matches' description='Up to five matches, each as "number · borrower · stage"')
        public List<String> matches;
        @InvocableVariable(label='Message' description='Plain-language result to show or act on')
        public String message;
    }

    @InvocableMethod(
        label='Find Loan Application'
        description='Finds loan applications by application number or borrower name. Use before Summarize Loan Application when the user names a loan but no loan record is open.'
        category='Loan Advisor'
    )
    public static List<Result> findApplications(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(findOne(req.searchTerm));
        }
        return results;
    }

    @TestVisible
    private static Result findOne(String searchTerm) {
        Result result = new Result();
        result.matches = new List<String>();

        String term = searchTerm == null ? '' : searchTerm.trim();
        if (term.length() < MIN_SEARCH_LENGTH) {
            result.message = 'Enter at least ' + MIN_SEARCH_LENGTH + ' characters of the application number or borrower name.';
            return result;
        }

        String likeTerm = '%' + escapeLike(term) + '%';
        Integer rowLimit = MAX_MATCHES + 1;
        List<Loan_Application__c> loans = [
            SELECT Id, Name, Account__r.Name, Stage__c
            FROM Loan_Application__c
            WHERE Name LIKE :likeTerm OR Account__r.Name LIKE :likeTerm
            WITH USER_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT :rowLimit
        ];

        for (Integer i = 0; i < loans.size() && i < MAX_MATCHES; i++) {
            result.matches.add(describeLoan(loans[i]));
        }

        if (loans.isEmpty()) {
            result.message = 'No loan application matches "' + term + '" that you have access to.';
        } else if (loans.size() == 1) {
            result.loanApplicationId = loans[0].Id;
            result.message = 'Found ' + loans[0].Name + '.';
        } else if (loans.size() > MAX_MATCHES) {
            result.message = 'More than ' + MAX_MATCHES + ' applications match. Ask the user for the application number.';
        } else {
            result.message = loans.size() + ' applications match. Ask the user which one they mean.';
        }
        return result;
    }

    private static String describeLoan(Loan_Application__c loan) {
        String borrower = loan.Account__r == null ? 'No borrower' : loan.Account__r.Name;
        String stage = loan.Stage__c == null ? 'No stage' : loan.Stage__c;
        return loan.Name + ' · ' + borrower + ' · ' + stage;
    }

    /** Escapes LIKE wildcards so user input is matched literally. */
    @TestVisible
    private static String escapeLike(String value) {
        return value.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');
    }
}
