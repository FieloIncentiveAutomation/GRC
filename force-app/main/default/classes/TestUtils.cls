@isTest
public with sharing class TestUtils {

    public static String guid(){
        Blob b = Crypto.GenerateAESKey(128);
        String h = EncodingUtil.ConvertTohex(b);
        String guid = h.SubString(0,8)+ '-' + h.SubString(8,12) + '-' + h.SubString(12,16) + '-' + h.SubString(16,20) + '-' + h.substring(20);
        return guid;
    }

    public static string getTimeStampBase62() {
        return toBase62(System.currentTimeMillis());
    }

    public static string toBase62(Integer n) {
        return toBase62((Long) n);
    }

    public static string toBase62(Long n) {
        List<String> numbers = new List<String>{
            '0','1','2','3','4','5','6','7','8','9',
            'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
            'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z'
        };
        List<String> digits = new List<String>();

        if (n == 0) {
            return '0';
        } else {
            while (n > 0) {
                if (digits.isEmpty()) {
                    digits.add(numbers.get(Math.mod(n, 62).intValue()));
                } else {
                    digits.add(0, numbers.get(Math.mod(n, 62).intValue()));
                }
                n = Math.ceil(n/62).longValue();
            }
            return String.join(digits,'');
        }
    }

    public static integer globalCounter = 0;
    private static Integer uniqueExternalIdCode(){
		return ++globalCounter;
	}

    public static List<FieloPLT__Program__c> createPrograms(String basename, Integer count) {
		List<FieloPLT__Program__c> results = new List<FieloPLT__Program__c>();
		for(Integer x = 0; x < count; x++){
			results.add(
				new FieloPLT__Program__c(
					Name = basename + x,
					FieloPLT__OnlineTransactionProcessing__c = true,
					FieloPLT__CapAdjustmentTransactions__c = true
				)
			);
		}
		Assert.isNotNull(results);
		return results;
	}

    public static List<FieloPLT__Promotion__c> createPromotions(String basename, Integer count, Id programId){
		List<FieloPLT__Promotion__c> results = new List<FieloPLT__Promotion__c>();
		for(Integer x = 0; x < count; x++){
			results.add(
				new FieloPLT__Promotion__c(
					Name = basename + x,
					FieloPLT__Program__c = programId
				)
			);
		}
		Assert.isNotNull(results);
		return results;
	}

    public static List<FieloPLT__Rule__c> createRules(String basename, Integer count, Id promotionId){
		List<FieloPLT__Rule__c> results = new List<FieloPLT__Rule__c>();
		for(Integer x = 0; x < count; x++){
			results.add(
				new FieloPLT__Rule__c(
					Name = basename + x,
					FieloPLT__Promotion__c = promotionId
				)
			);
		}
		Assert.isNotNull(results);
		return results;
	}

    public static FieloPLT__RuleTrigger__c createBehaviorType(
        String name,
        String objectName,
        String conditionField,
        String conditionValue,
        String dateField,
        String lookUpFromTransaction,
        String lookUpFromTracker
    ){
		FieloPLT__RuleTrigger__c rt = new FieloPLT__RuleTrigger__c(
			Name = name,
			FieloPLT__Object__c = objectName,
			FieloPLT__ConditionField__c = conditionField,
			FieloPLT__ConditionValue__c = conditionValue,
			FieloPLT__Date__c = dateField,
			FieloPLT__LookupFromTransaction__c = lookUpFromTransaction,
			FieloPLT__LookupFromTracker__c = lookUpFromTracker,
			FieloPLT__Prefix__c = ((sObject)Type.forName(objectName).newInstance()).getSObjectType().getDescribe().getKeyPrefix(),
			FieloPLT__ExternalId__c = objectName + '-' + name + uniqueExternalIdCode(),
			FieloPLT__Status__c = 'Active'
		);
		Assert.isNotNull(rt);
		return rt;
	}

    public static FieloPLT__Action__c createAction(String targetMember, Id behaviorTypeId){
		FieloPLT__Action__c action = new FieloPLT__Action__c(
			FieloPLT__TargetMember__c = targetMember,
			FieloPLT__RuleTrigger__c = behaviorTypeId,
			FieloPLT__ExternalId__c = behaviorTypeId + '-' + targetMember + uniqueExternalIdCode()
		);
		Assert.isNotNull(action);
		return action;
	}

    public static List<FieloPLT__Criterion__c> createCriteria(Id parentId, Integer count){
		List<FieloPLT__Criterion__c> results = new List<FieloPLT__Criterion__c>();

        String fieldName = parentId.getSobjectType().getDescribe().getName();

		for(Integer x = 0; x < count; x++){
			results.add(
				new FieloPLT__Criterion__c(
					FieloPLT__ExternalId__c = parentId + '-' + x + uniqueExternalIdCode()
				)
			);
            results.get(results.size()-1).put(fieldName, parentId);
		}
		Assert.isNotNull(results);
		return results;
	}

    public static FieloPLT__PointType__c createRebateCurrency(){
		return new FieloPLT__PointType__c(
			Name = 'Dollar',
			FieloPLT__MemberBalanceField__c = 'Rebate__c',
			FieloPLT__TransactionBalanceField__c = 'Rebate__c',
			FieloPLT__ConversionModeField__c = 'RebateConversionMode__c',
			FieloPLT__ConversionValueField__c = 'RebateConversionValue__c',
			FieloPLT__RecordFieldNameField__c = 'RebateFieldName__c',
			FieloPLT__DecimalsNumber__c = 2,
			FieloPLT__GeneratePayout__c = true
		);
	}

    public static List<FieloPLT__Member__c> createIndividualMember(String basename, Integer count, Id programId){
		List<FieloPLT__Member__c> results = new List<FieloPLT__Member__c>();
		for(Integer x = 0; x < count; x++){
			results.add(
				new FieloPLT__Member__c(
					Name = basename + x,
					FieloPLT__Email__c = (basename + x).deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
					FieloPLT__Program__c = programId,
					FieloPLT__Type__c = 'Individual Account'
				)
			);
		}
		Assert.isNotNull(results);
		return results;
	}
}