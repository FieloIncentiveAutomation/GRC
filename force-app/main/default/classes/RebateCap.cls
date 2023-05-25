global with sharing class RebateCap implements FieloPLT.RuleRewarding{

    // fixed %, could be stored in a CustomSetting
    public static final Decimal REBATE_CAP_PERCENT = 0.05;
    // Only works for Rebate currency
    public static final String REBATE_FIELD = 'Rebate__c';

    global void reflectionRewarding(List<FieloPLT__Transaction__c> transactions){
        Set<Id> recordIds = new Set<Id>();
        Set<Id> opportunityIds = new Set<Id>();
        Map<Id, Decimal> capByOpportunity = new Map<Id, Decimal>();
        Map<Id, Decimal> decreaseByOpportunity = new Map<Id, Decimal>();
        Map<Id, List<FieloPLT__Transaction__c>> transactionsByRecord = new Map<Id, List<FieloPLT__Transaction__c>>();
        Map<Id, List<FieloPLT__Transaction__c>> transactionsByOpportunity = new Map<Id, List<FieloPLT__Transaction__c>>();
        Map<Id, List<FieloPLT__Point__c>> pointsByTransaction = new Map<Id, List<FieloPLT__Point__c>>();

        // Getting all QP from Transactions
        for(FieloPLT__Transaction__c t : transactions) {
            // ignores transactions that are not rebate
            if (t.QuarterlyPerformance__c != null && t.get(REBATE_FIELD) != null) {
                recordIds.add(t.QuarterlyPerformance__c);
                if (transactionsByRecord.containsKey(t.QuarterlyPerformance__c)) {
                    transactionsByRecord.get(t.QuarterlyPerformance__c).add(t);
                } else {
                    transactionsByRecord.put(t.QuarterlyPerformance__c, new List<FieloPLT__Transaction__c>{t});
                }
            }

        }

        Map<Id, QuarterlyPerformance__c> recordsMap =
            new Map<Id, QuarterlyPerformance__c>(
                (List<QuarterlyPerformance__c>)QueryUtils.getRecords(recordIds, new Set<String>{'Opportunity__r.Amount'}));

        // Getting all Opportunities from QPs
        for (QuarterlyPerformance__c qp : recordsMap.values()) {
            opportunityIds.add(qp.Opportunity__c);
            if (!capByOpportunity.containsKey(qp.Opportunity__c)) {
                capByOpportunity.put(qp.Opportunity__c, qp.Opportunity__r.Amount * REBATE_CAP_PERCENT);
            }
            if (transactionsByOpportunity.containsKey(qp.Opportunity__c)) {
                transactionsByOpportunity.get(qp.Opportunity__c).addAll(transactionsByRecord.get(qp.Id));
            } else {
                transactionsByOpportunity.put(qp.Opportunity__c, transactionsByRecord.get(qp.Id).deepClone(true,true,true));
            }
        }

        // Checking accumulated Rebate for Opportunities:
        List<AggregateResult> result = (List<AggregateResult>) Database.query(
            'SELECT ' +
                'QuarterlyPerformance__r.Opportunity__c OppID, SUM(Rebate__c) TotalRebate ' +
            'FROM FieloPLT__Transaction__c ' +
            'WHERE QuarterlyPerformance__r.Opportunity__c IN :opportunityIds ' +
            'GROUP BY QuarterlyPerformance__r.Opportunity__c'
        );

        // Check the ones that are above the cap limit
        for (AggregateResult ar : result) {
            Id oppId = Id.valueOf(String.valueOf(ar.get('OppID')));
            Decimal totalRebate = (Decimal) ar.get('TotalRebate');
            if (totalRebate > capByOpportunity.get(oppId)) {
                decreaseByOpportunity.put(
                    oppId,
                    totalRebate - capByOpportunity.get(oppId)
                );
            }
        }

        // if there is something to cap
        if (!decreaseByOpportunity.isEmpty()) {
            Map<Id, FieloPLT__Member__c> updateMembersMap = new Map<Id, FieloPLT__Member__c>();
            Map<Id, FieloPLT__Transaction__c> updateTransactionsMap = new Map<Id, FieloPLT__Transaction__c>();
            Map<Id, FieloPLT__Point__c> updatePointsMap = new Map<Id, FieloPLT__Point__c>();
            Map<Id, FieloPLT__Payout__c> updatePayoutMap = new Map<Id, FieloPLT__Payout__c>();
            Set<Id> transactionIds = new Map<Id, FieloPLT__Transaction__c>(transactions).keySet();
            Set<Id> memberIds = new Set<Id>();
            Set<Id> payoutIds = new Set<Id>();

            for(FieloPLT__Point__c p : (List<FieloPLT__Point__c>) QueryUtils.getRecords('FieloPLT__Point__c', 'FieloPLT__Transaction__c', transactionIds)) {
                if (pointsByTransaction.containsKey(p.FieloPLT__Transaction__c)) {
                    pointsByTransaction.get(p.FieloPLT__Transaction__c).add(p);
                } else {
                    pointsByTransaction.put (p.FieloPLT__Transaction__c, new List<FieloPLT__Point__c>{p});
                }
                memberIds.add(p.FieloPLT__Member__c);
                payoutIds.add(p.FieloPLT__Payout__c);
            }

            Map<Id, FieloPLT__Member__c> membersMap = new Map<Id, FieloPLT__Member__c>((List<FieloPLT__Member__c>)QueryUtils.getRecords(memberIds));
            Map<Id, FieloPLT__Payout__c> payoutMap = new Map<Id, FieloPLT__Payout__c>((List<FieloPLT__Payout__c>)QueryUtils.getRecords(payoutIds));

            for (Id oppId : decreaseByOpportunity.keySet()) {
                for (FieloPLT__Transaction__c t : transactionsByOpportunity.get(oppId)) {
                    if (decreaseByOpportunity.get(oppId) <= 0) break;

                    Boolean eraseTransaction = decreaseByOpportunity.get(oppId) >= t.Rebate__c;
                    Decimal dec = eraseTransaction ?
                        t.Rebate__c :
                        t.Rebate__c - decreaseByOpportunity.get(oppId);

                    updateTransactionsMap.put(
                        t.Id,
                        new FieloPLT__Transaction__c(
                            Id = t.Id,
                            Rebate__c = (t.Rebate__c - dec)
                        )
                    );

                    Decimal decPoints = dec;
                    for (FieloPLT__Point__c p : pointsByTransaction.get(t.Id)) {
                        if (eraseTransaction) {

                            membersMap.get(p.FieloPLT__Member__c).Rebate__c = membersMap.get(p.FieloPLT__Member__c).Rebate__c - p.FieloPLT__TotalPoints__c;
                            payoutMap.get(p.FieloPLT__Payout__c).FieloPLT__Amount__c = payoutMap.get(p.FieloPLT__Payout__c).FieloPLT__Amount__c - p.FieloPLT__TotalPoints__c;

                            p.FieloPLT__TotalPoints__c = 0;
                        } else {
                            if (decPoints == 0) break;
                            Decimal decPoint = decPoints > p.FieloPLT__TotalPoints__c ?
                                p.FieloPLT__TotalPoints__c :
                                p.FieloPLT__TotalPoints__c - decPoints;
                            p.FieloPLT__TotalPoints__c = (p.FieloPLT__TotalPoints__c - decPoint);
                            decPoints -= decPoint;

                            membersMap.get(p.FieloPLT__Member__c).Rebate__c = membersMap.get(p.FieloPLT__Member__c).Rebate__c - decPoint;
                            payoutMap.get(p.FieloPLT__Payout__c).FieloPLT__Amount__c = payoutMap.get(p.FieloPLT__Payout__c).FieloPLT__Amount__c - decPoint;
                        }

                        updateMembersMap.put(
                            p.FieloPLT__Member__c,
                            new FieloPLT__Member__c(
                                Id = p.FieloPLT__Member__c,
                                Rebate__c = membersMap.get(p.FieloPLT__Member__c).Rebate__c
                            )
                        );
                        updatePayoutMap.put(
                            p.FieloPLT__Payout__c,
                            new FieloPLT__Payout__c(
                                Id = p.FieloPLT__Payout__c,
                                FieloPLT__Amount__c = payoutMap.get(p.FieloPLT__Payout__c).FieloPLT__Amount__c
                            )
                        );
                        updatePointsMap.put(
                            p.Id,
                            new FieloPLT__Point__c(
                                Id = p.Id,
                                FieloPLT__TotalPoints__c = p.FieloPLT__TotalPoints__c
                            )
                        );
                    }
                    decreaseByOpportunity.put(oppId, decreaseByOpportunity.get(oppId) - dec);
                }
            }

            FieloPLT.SObjectService.enableAdminPermission(true);
            update updatePointsMap.values();
            update updateTransactionsMap.values();
            update updatePayoutMap.values();
            update updateMembersMap.values();
            FieloPLT.SObjectService.enableAdminPermission(false);
        }
    }

	global void revertRewarding(List<FieloPLT__Transaction__c> transactions) {
    }
}