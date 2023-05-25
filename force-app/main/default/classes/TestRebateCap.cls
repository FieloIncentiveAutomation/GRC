@isTest
public with sharing class TestRebateCap {

    public static final String CLASS_NAME = 'RebateCap';
    public static FieloPLT__RuleTrigger__c behaviorType;
    public static FieloPLT__Action__c action;
    public static FieloPLT__Program__c program;
    public static FieloPLT__PointType__c rebateCurrency;
    public static Map<Id, FieloPLT__Promotion__c> promotionsMap;
    public static Map<Id, FieloPLT__Rule__c> rulesMap;

    static {
        behaviorType =
            TestUtils.createBehaviorType(
                'Quarterly Performance',
                'QuarterlyPerformance__c',
                null,
                null,
                'CreatedDate',
                'QuarterlyPerformance__c',
                'QuarterlyPerformance__c'
            );
        insert behaviorType;

        action =
            TestUtils.createAction(
                'Member__c',
                behaviorType.Id
            );
        insert action;

        rebateCurrency = TestUtils.createRebateCurrency();
        insert rebateCurrency;

        rebateCurrency.FieloPLT__Status__c = 'Active';
        FieloPLT.SObjectService.enableAdminPermission(true);
        update rebateCurrency;
        FieloPLT.SObjectService.enableAdminPermission(false);

        program = TestUtils.createPrograms('Program', 1)[0];
        insert program;
    }


    @istest
    static void calculateRebateWithoutCap(){
        //Promotion
        List<FieloPLT__Promotion__c> promotions = TestUtils.createPromotions('Quarterly Promotion', 1, program.Id);
        insert promotions;

        //Rule
        List<FieloPLT__Rule__c> rules = TestUtils.createRules('Quarterly Rule', 1, promotions.get(0).Id);
        rules.get(0).RebateConversionMode__c = 'Percentage';
        rules.get(0).RebateFieldName__c = 'Consumption__c';
        rules.get(0).RebateConversionValue__c = 5;
        rules.get(0).FieloPLT__Action__c = action.Id;
        rules.get(0).FieloPLT__Promotion__c = promotions.get(0).Id;
        rules.get(0).FieloPLT__RelatedList__c = 'QuarterlyPerformance__c';
        rules.get(0).FieloPLT__Type__c = 'No Competition';
        rules.get(0).FieloPLT__PayoutDateMode__c = 'Specific Date';

        Date refDate = System.today().addMonths(1);
        rules.get(0).FieloPLT__PayoutDate__c = Date.newInstance(refDate.year(),refDate.month(),10);

        insert rules;

        // Criterion related to the rule
        List<FieloPLT__Criterion__c> criteriaRule = TestUtils.createCriteria(rules[0].Id, 1);
        criteriaRule[0].FieloPLT__Order__c = 1;
        criteriaRule[0].FieloPLT__FieldName__c = 'Consumption__c';
        criteriaRule[0].FieloPLT__Operator__c = 'greater than';
        criteriaRule[0].FieloPLT__NumberValue__c = 0;
        insert criteriaRule;

        promotions[0].FieloPLT__Status__c = 'Active';
        update promotions;

        List<FieloPLT__Member__c> members =  TestUtils.createIndividualMember('Member ', 1, program.Id);
        insert members;

        Opportunity opp = new Opportunity(
            Name = 'Opp 1',
            Amount = 10000,
            CloseDate = System.today(),
            Probability = 60,
            StageName = 'Prospecting'
        );
        insert opp;

        // When
        Test.startTest();
            FieloPLT.SObjectService.setStaticVariables();

            List<QuarterlyPerformance__c> qps = new List<QuarterlyPerformance__c>{
                new QuarterlyPerformance__c(
                    Member__c = members.get(0).Id,
                    Opportunity__c = opp.Id,
                    Consumption__c = 2000,
                    Quarter__c = '2022-Q1'
                ),
                new QuarterlyPerformance__c(
                    Member__c = members.get(0).Id,
                    Opportunity__c = opp.Id,
                    Consumption__c = 5000,
                    Quarter__c = '2022-Q2'
                ),
                new QuarterlyPerformance__c(
                    Member__c = members.get(0).Id,
                    Opportunity__c = opp.Id,
                    Consumption__c = 5000,
                    Quarter__c = '2022-Q3'
                )
            };
            insert qps;
        Test.stopTest();

        // Then
        // Then
        FieloPLT__Member__c member = (FieloPLT__Member__c) QueryUtils.getRecord(members.get(0).Id);
        List<FieloPLT__Payout__c> payouts = (List<FieloPLT__Payout__c>) QueryUtils.getRecords('FieloPLT__Payout__c', 'FieloPLT__Member__c', members.get(0).Id);

        Assert.areEqual(600, member.Rebate__c, 'Wrong Rebate Balance');
        Assert.areEqual(600, payouts.get(0).FieloPLT__Amount__c, 'Wrong Payout Balance');
    }

    @istest
    static void calculateRebateWithCap(){
        //Promotion
        List<FieloPLT__Promotion__c> promotions = TestUtils.createPromotions('Quarterly Promotion', 1, program.Id);
        insert promotions;

        //Rule
        List<FieloPLT__Rule__c> rules = TestUtils.createRules('Quarterly Rule', 1, promotions.get(0).Id);
        rules.get(0).RebateConversionMode__c = 'Percentage';
        rules.get(0).RebateFieldName__c = 'Consumption__c';
        rules.get(0).RebateConversionValue__c = 5;
        rules.get(0).FieloPLT__Action__c = action.Id;
        rules.get(0).FieloPLT__Promotion__c = promotions.get(0).Id;
        rules.get(0).FieloPLT__RelatedList__c = 'QuarterlyPerformance__c';
        rules.get(0).FieloPLT__Type__c = 'No Competition';
        rules.get(0).FieloPLT__PayoutDateMode__c = 'Specific Date';
        rules.get(0).FieloPLT__RewardDeliveryClass__c = CLASS_NAME;

        Date refDate = System.today().addMonths(1);
        rules.get(0).FieloPLT__PayoutDate__c = Date.newInstance(refDate.year(),refDate.month(),10);

        insert rules;

        // Criterion related to the rule
        List<FieloPLT__Criterion__c> criteriaRule = TestUtils.createCriteria(rules[0].Id, 1);
        criteriaRule[0].FieloPLT__Order__c = 1;
        criteriaRule[0].FieloPLT__FieldName__c = 'Consumption__c';
        criteriaRule[0].FieloPLT__Operator__c = 'greater than';
        criteriaRule[0].FieloPLT__NumberValue__c = 0;
        insert criteriaRule;

        promotions[0].FieloPLT__Status__c = 'Active';
        update promotions;

        List<FieloPLT__Member__c> members =  TestUtils.createIndividualMember('Member ', 1, program.Id);
        insert members;

        Opportunity opp = new Opportunity(
            Name = 'Opp 1',
            Amount = 10000,
            CloseDate = System.today(),
            Probability = 60,
            StageName = 'Prospecting'
        );
        insert opp;

        // When
        Test.startTest();
            FieloPLT.SObjectService.setStaticVariables();

            List<QuarterlyPerformance__c> qps = new List<QuarterlyPerformance__c>{
                new QuarterlyPerformance__c(
                    Member__c = members.get(0).Id,
                    Opportunity__c = opp.Id,
                    Consumption__c = 2000,
                    Quarter__c = '2022-Q1'
                ),
                new QuarterlyPerformance__c(
                    Member__c = members.get(0).Id,
                    Opportunity__c = opp.Id,
                    Consumption__c = 5000,
                    Quarter__c = '2022-Q2'
                ),
                new QuarterlyPerformance__c(
                    Member__c = members.get(0).Id,
                    Opportunity__c = opp.Id,
                    Consumption__c = 5000,
                    Quarter__c = '2022-Q3'
                )
            };
            insert qps;
        Test.stopTest();

        // Then
        FieloPLT__Member__c member = (FieloPLT__Member__c) QueryUtils.getRecord(members.get(0).Id);
        List<FieloPLT__Transaction__c> transactions = (List<FieloPLT__Transaction__c>) QueryUtils.getRecords('FieloPLT__Transaction__c', 'FieloPLT__Member__c', members.get(0).Id);
        List<FieloPLT__Payout__c> payouts = (List<FieloPLT__Payout__c>) QueryUtils.getRecords('FieloPLT__Payout__c', 'FieloPLT__Member__c', members.get(0).Id);

        Assert.areEqual(500, member.Rebate__c, 'Wrong Rebate Balance');
        Assert.areEqual(500, payouts.get(0).FieloPLT__Amount__c, 'Wrong Payout Balance');
    }

    @istest
    static void calculateRebateWithCapBULK(){
        //Promotion
        List<FieloPLT__Promotion__c> promotions = TestUtils.createPromotions('Quarterly Promotion', 1, program.Id);
        insert promotions;

        //Rule
        List<FieloPLT__Rule__c> rules = TestUtils.createRules('Quarterly Rule', 1, promotions.get(0).Id);
        rules.get(0).RebateConversionMode__c = 'Percentage';
        rules.get(0).RebateFieldName__c = 'Consumption__c';
        rules.get(0).RebateConversionValue__c = 5;
        rules.get(0).FieloPLT__Action__c = action.Id;
        rules.get(0).FieloPLT__Promotion__c = promotions.get(0).Id;
        rules.get(0).FieloPLT__RelatedList__c = 'QuarterlyPerformance__c';
        rules.get(0).FieloPLT__Type__c = 'No Competition';
        rules.get(0).FieloPLT__PayoutDateMode__c = 'Specific Date';
        rules.get(0).FieloPLT__RewardDeliveryClass__c = CLASS_NAME;

        Date refDate = System.today().addMonths(1);
        rules.get(0).FieloPLT__PayoutDate__c = Date.newInstance(refDate.year(),refDate.month(),10);

        insert rules;

        // Criterion related to the rule
        List<FieloPLT__Criterion__c> criteriaRule = TestUtils.createCriteria(rules[0].Id, 1);
        criteriaRule[0].FieloPLT__Order__c = 1;
        criteriaRule[0].FieloPLT__FieldName__c = 'Consumption__c';
        criteriaRule[0].FieloPLT__Operator__c = 'greater than';
        criteriaRule[0].FieloPLT__NumberValue__c = 0;
        insert criteriaRule;

        promotions[0].FieloPLT__Status__c = 'Active';
        update promotions;

        List<FieloPLT__Member__c> members =  TestUtils.createIndividualMember('Member ', 1, program.Id);
        insert members;

        Opportunity opp = new Opportunity(
            Name = 'Opp 1',
            Amount = 10000,
            CloseDate = System.today(),
            Probability = 60,
            StageName = 'Prospecting'
        );
        insert opp;

        // When
        Test.startTest();
            FieloPLT.SObjectService.setStaticVariables();

            insert new QuarterlyPerformance__c(
                Member__c = members.get(0).Id,
                Opportunity__c = opp.Id,
                Consumption__c = 10000,
                Quarter__c = '2022-Q1'
            );
            List<QuarterlyPerformance__c> qps = new List<QuarterlyPerformance__c>();
            for(Integer i = 1; i<= 200;i++) {
                qps.add(
                    new QuarterlyPerformance__c(
                        Member__c = members.get(0).Id,
                        Opportunity__c = opp.Id,
                        Consumption__c = 20,
                        Quarter__c = '2022-Q1'
                    )
                );
            }
            insert qps;
        Test.stopTest();

        // Then
        FieloPLT__Member__c member = (FieloPLT__Member__c) QueryUtils.getRecord(members.get(0).Id);
        List<FieloPLT__Transaction__c> transactions = (List<FieloPLT__Transaction__c>) QueryUtils.getRecords('FieloPLT__Transaction__c', 'FieloPLT__Member__c', members.get(0).Id);
        List<FieloPLT__Payout__c> payouts = (List<FieloPLT__Payout__c>) QueryUtils.getRecords('FieloPLT__Payout__c', 'FieloPLT__Member__c', members.get(0).Id);

        Assert.areEqual(500, member.Rebate__c, 'Wrong Rebate Balance');
        Assert.areEqual(500, payouts.get(0).FieloPLT__Amount__c, 'Wrong Payout Balance');
    }

    @istest
    static void calculateRebateWithCapBULK_2(){
        //Promotion
        List<FieloPLT__Promotion__c> promotions = TestUtils.createPromotions('Quarterly Promotion', 1, program.Id);
        insert promotions;

        //Rule
        List<FieloPLT__Rule__c> rules = TestUtils.createRules('Quarterly Rule', 1, promotions.get(0).Id);
        rules.get(0).RebateConversionMode__c = 'Percentage';
        rules.get(0).RebateFieldName__c = 'Consumption__c';
        rules.get(0).RebateConversionValue__c = 5;
        rules.get(0).FieloPLT__Action__c = action.Id;
        rules.get(0).FieloPLT__Promotion__c = promotions.get(0).Id;
        rules.get(0).FieloPLT__RelatedList__c = 'QuarterlyPerformance__c';
        rules.get(0).FieloPLT__Type__c = 'No Competition';
        rules.get(0).FieloPLT__PayoutDateMode__c = 'Specific Date';
        rules.get(0).FieloPLT__RewardDeliveryClass__c = CLASS_NAME;

        Date refDate = System.today().addMonths(1);
        rules.get(0).FieloPLT__PayoutDate__c = Date.newInstance(refDate.year(),refDate.month(),10);

        insert rules;

        // Criterion related to the rule
        List<FieloPLT__Criterion__c> criteriaRule = TestUtils.createCriteria(rules[0].Id, 1);
        criteriaRule[0].FieloPLT__Order__c = 1;
        criteriaRule[0].FieloPLT__FieldName__c = 'Consumption__c';
        criteriaRule[0].FieloPLT__Operator__c = 'greater than';
        criteriaRule[0].FieloPLT__NumberValue__c = 0;
        insert criteriaRule;

        promotions[0].FieloPLT__Status__c = 'Active';
        update promotions;

        List<FieloPLT__Member__c> members =  TestUtils.createIndividualMember('Member ', 1, program.Id);
        insert members;

        Opportunity opp = new Opportunity(
            Name = 'Opp 1',
            Amount = 10000,
            CloseDate = System.today(),
            Probability = 60,
            StageName = 'Prospecting'
        );
        insert opp;

        // When
        Test.startTest();
            FieloPLT.SObjectService.setStaticVariables();

            insert new QuarterlyPerformance__c(
                Member__c = members.get(0).Id,
                Opportunity__c = opp.Id,
                Consumption__c = 10000,
                Quarter__c = '2022-Q1'
            );
            List<QuarterlyPerformance__c> qps = new List<QuarterlyPerformance__c>();
            for(Integer i = 1; i<= 200;i++) {
                qps.add(
                    new QuarterlyPerformance__c(
                        Member__c = members.get(0).Id,
                        Opportunity__c = opp.Id,
                        Consumption__c = 35,
                        Quarter__c = '2022-Q1'
                    )
                );
            }
            insert qps;
        Test.stopTest();

        // Then
        FieloPLT__Member__c member = (FieloPLT__Member__c) QueryUtils.getRecord(members.get(0).Id);
        List<FieloPLT__Transaction__c> transactions = (List<FieloPLT__Transaction__c>) QueryUtils.getRecords('FieloPLT__Transaction__c', 'FieloPLT__Member__c', members.get(0).Id);
        List<FieloPLT__Payout__c> payouts = (List<FieloPLT__Payout__c>) QueryUtils.getRecords('FieloPLT__Payout__c', 'FieloPLT__Member__c', members.get(0).Id);

        Assert.areEqual(500, member.Rebate__c, 'Wrong Rebate Balance');
        Assert.areEqual(500, payouts.get(0).FieloPLT__Amount__c, 'Wrong Payout Balance');
    }
}