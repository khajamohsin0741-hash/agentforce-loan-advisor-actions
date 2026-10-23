/**
 * Deterministic next-best-action rules for a loan application.
 *
 * The agent's language model explains these recommendations to the advisor, but the
 * recommendations themselves come from explicit, testable rules rather than from the model.
 * Thresholds live in the Loan_Rule_Setting__mdt "Default" record so credit policy can change
 * them without a deployment. The constants below are only fallbacks. Values are illustrative,
 * not lending policy.
 */
public with sharing class LoanNextBestActionRules {
    public static final Decimal DEFAULT_DTI_GUIDELINE = 43;
    public static final Integer DEFAULT_UNDERWRITING_TARGET_DAYS = 10;
    public static final String SETTINGS_RECORD = 'Default';

    public class Facts {
        public String stage;
        public Decimal debtToIncome;
        public String creditBand;
        public List<String> missingDocuments = new List<String>();
        public Integer daysInStage;
    }

    public class Settings {
        public Decimal dtiGuideline = DEFAULT_DTI_GUIDELINE;
        public Integer underwritingTargetDays = DEFAULT_UNDERWRITING_TARGET_DAYS;
    }

    /** Reads thresholds from custom metadata, falling back to the defaults for blank values. */
    public static Settings loadSettings() {
        Settings settings = new Settings();
        Loan_Rule_Setting__mdt settingRecord = Loan_Rule_Setting__mdt.getInstance(SETTINGS_RECORD);
        if (settingRecord != null) {
            if (settingRecord.DTI_Guideline__c != null) {
                settings.dtiGuideline = settingRecord.DTI_Guideline__c;
            }
            if (settingRecord.Underwriting_Target_Days__c != null) {
                settings.underwritingTargetDays = settingRecord.Underwriting_Target_Days__c.intValue();
            }
        }
        return settings;
    }

    public static List<String> recommend(Facts facts) {
        return recommend(facts, loadSettings());
    }

    public static List<String> recommend(Facts facts, Settings settings) {
        List<String> actions = new List<String>();

        if (facts.stage == 'Declined') {
            actions.add('Application is declined. Confirm the adverse action notice was sent and log the customer conversation.');
            return actions;
        }
        if (facts.stage == 'Funded') {
            actions.add('Loan is funded. No pipeline action needed; consider a relationship follow-up.');
            return actions;
        }

        if (!facts.missingDocuments.isEmpty()) {
            actions.add('Request missing documents: ' + String.join(facts.missingDocuments, ', ') + '.');
        }
        if (facts.debtToIncome != null && facts.debtToIncome > settings.dtiGuideline) {
            actions.add(
                'Debt-to-income is ' + facts.debtToIncome.setScale(1) + '%, above the ' +
                settings.dtiGuideline.stripTrailingZeros().toPlainString() +
                '% guideline. Review income documentation or discuss a lower amount or a co-borrower.'
            );
        }
        if (facts.creditBand == 'D') {
            actions.add('Credit band D. Route to a senior underwriter before discussing terms.');
        }
        if (
            facts.stage == 'Underwriting' &&
            facts.daysInStage != null &&
            facts.daysInStage > settings.underwritingTargetDays
        ) {
            actions.add(
                'In underwriting for ' + facts.daysInStage + ' days (target ' + settings.underwritingTargetDays +
                '). Escalate to the underwriting manager.'
            );
        }
        if (facts.stage == 'Approved') {
            actions.add('Approved. Schedule closing and send closing disclosures.');
        }
        if (actions.isEmpty()) {
            actions.add('No action needed. The application is on track.');
        }
        return actions;
    }

    /** Splits the semicolon-separated Missing_Documents__c value into clean items. */
    public static List<String> parseDocuments(String raw) {
        List<String> docs = new List<String>();
        if (String.isBlank(raw)) {
            return docs;
        }
        for (String part : raw.split(';')) {
            if (String.isNotBlank(part)) {
                docs.add(part.trim());
            }
        }
        return docs;
    }
}
