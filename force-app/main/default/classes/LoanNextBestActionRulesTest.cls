@IsTest
private class LoanNextBestActionRulesTest {
    private static LoanNextBestActionRules.Facts facts(String stage) {
        LoanNextBestActionRules.Facts f = new LoanNextBestActionRules.Facts();
        f.stage = stage;
        return f;
    }

    @IsTest
    static void onTrackApplicationNeedsNoAction() {
        LoanNextBestActionRules.Facts f = facts('Underwriting');
        f.debtToIncome = 30;
        f.creditBand = 'A';
        f.daysInStage = 2;
        List<String> actions = LoanNextBestActionRules.recommend(f);
        Assert.areEqual(1, actions.size());
        Assert.isTrue(actions[0].startsWith('No action needed'));
    }

    @IsTest
    static void flagsMissingDocsHighDtiWeakCreditAndSlowUnderwriting() {
        LoanNextBestActionRules.Facts f = facts('Underwriting');
        f.missingDocuments = new List<String>{ '2025 tax return', 'Bank statements' };
        f.debtToIncome = 47.26;
        f.creditBand = 'D';
        f.daysInStage = 14;

        List<String> actions = LoanNextBestActionRules.recommend(f);

        Assert.areEqual(4, actions.size());
        Assert.areEqual('Request missing documents: 2025 tax return, Bank statements.', actions[0]);
        Assert.isTrue(actions[1].contains('47.3%'), actions[1]);
        Assert.isTrue(actions[2].contains('senior underwriter'));
        Assert.isTrue(actions[3].contains('14 days'));
    }

    @IsTest
    static void dtiAtGuidelineIsNotFlagged() {
        LoanNextBestActionRules.Facts f = facts('Intake');
        f.debtToIncome = LoanNextBestActionRules.DEFAULT_DTI_GUIDELINE;
        Assert.isTrue(LoanNextBestActionRules.recommend(f)[0].startsWith('No action needed'));
    }

    @IsTest
    static void approvedLoanSchedulesClosing() {
        Assert.isTrue(LoanNextBestActionRules.recommend(facts('Approved'))[0].contains('Schedule closing'));
    }

    @IsTest
    static void terminalStagesShortCircuit() {
        LoanNextBestActionRules.Facts declined = facts('Declined');
        declined.missingDocuments = new List<String>{ 'ID' };
        List<String> actions = LoanNextBestActionRules.recommend(declined);
        Assert.areEqual(1, actions.size());
        Assert.isTrue(actions[0].contains('adverse action'));
        Assert.isTrue(LoanNextBestActionRules.recommend(facts('Funded'))[0].contains('funded'));
    }

    @IsTest
    static void parsesDocumentList() {
        Assert.areEqual(new List<String>{ 'Pay stubs', 'W-2' }, LoanNextBestActionRules.parseDocuments(' Pay stubs ; ;W-2;'));
        Assert.areEqual(0, LoanNextBestActionRules.parseDocuments(null).size());
        Assert.areEqual(0, LoanNextBestActionRules.parseDocuments('  ').size());
    }

    @IsTest
    static void customThresholdsChangeRecommendations() {
        LoanNextBestActionRules.Settings strict = new LoanNextBestActionRules.Settings();
        strict.dtiGuideline = 36;
        strict.underwritingTargetDays = 5;

        LoanNextBestActionRules.Facts f = facts('Underwriting');
        f.debtToIncome = 38;
        f.daysInStage = 6;

        List<String> actions = LoanNextBestActionRules.recommend(f, strict);
        Assert.areEqual(2, actions.size(), String.valueOf(actions));
        Assert.isTrue(actions[0].contains('above the 36% guideline'), actions[0]);
        Assert.isTrue(actions[1].contains('(target 5)'), actions[1]);

        // The same application is on track under the default thresholds.
        Assert.isTrue(LoanNextBestActionRules.recommend(f, new LoanNextBestActionRules.Settings())[0].startsWith('No action needed'));
    }

    @IsTest
    static void loadsDeployedDefaultSettings() {
        LoanNextBestActionRules.Settings settings = LoanNextBestActionRules.loadSettings();
        Assert.areEqual(43, settings.dtiGuideline.intValue());
        Assert.areEqual(10, settings.underwritingTargetDays);
    }
}
