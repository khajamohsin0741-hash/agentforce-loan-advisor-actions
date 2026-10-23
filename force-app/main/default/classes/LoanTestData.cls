/**
 * Shared test data. All names are fictitious.
 */
@IsTest
public class LoanTestData {
    /** Standard User with the Loan_Advisor_Agent permission set (least privilege). */
    public static User advisor() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'advisor',
            Email = 'advisor.' + unique + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Advisor',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'advisor.' + unique + '@example.com.demo'
        );
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Loan_Advisor_Agent' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        return u;
    }

    public static Loan_Application__c loan(Id accountId, Id ownerId, String stage) {
        return new Loan_Application__c(Account__c = accountId, OwnerId = ownerId, Stage__c = stage, Product__c = 'Small Business');
    }
}
