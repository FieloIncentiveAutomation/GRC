public class QueryUtils {
    public static List<SObject> getRecords(Set<Id> recordIds) {
        DescribeSObjectResult objDesc = new List<Id>(recordIds).get(0).getSObjectType().getDescribe();
        return Database.query(
            'SELECT ' +
                String.join(new List<String>(objDesc.fields.getMap().keySet()), ',') +
            ' FROM ' +
                objDesc.getName() + ' WHERE Id IN :recordIds'
        );
    }

	public static List<SObject> getRecords(Set<Id> recordIds, Set<String> extraFields) {
        DescribeSObjectResult objDesc = new List<Id>(recordIds).get(0).getSObjectType().getDescribe();
		if (extraFields == null) extraFields = new Set<String>();
        return Database.query(
            'SELECT ' +
                String.join(new List<String>(objDesc.fields.getMap().keySet()), ',') +
                (extraFields.isEmpty() ? '' : (',' + String.join(new List<String>(extraFields), ','))) +
            ' FROM ' +
                objDesc.getName() + ' WHERE Id IN :recordIds'
        );
    }

	public static List<SObject> getRecords(String objectName, String fieldName, Object value) {
        DescribeSObjectResult objDesc = Schema.describeSObjects(new List<String>{objectName}).get(0);
        return Database.queryWithBinds(
			'SELECT ' +
                String.join(new List<String>(objDesc.fields.getMap().keySet()), ',') +
            ' FROM ' +
                objDesc.getName() + ' WHERE '+fieldName+' = :value',
			new Map<String,Object> {
				'value' => value
			},
			AccessLevel.SYSTEM_MODE
        );
    }

    public static List<SObject> getRecords(String objectName, String fieldName, Object value, String orderBy) {
        DescribeSObjectResult objDesc = Schema.describeSObjects(new List<String>{objectName}).get(0);
        return Database.queryWithBinds(
			'SELECT ' +
                String.join(new List<String>(objDesc.fields.getMap().keySet()), ',') +
            ' FROM ' +
                objDesc.getName() + ' WHERE '+fieldName+' = :value ' +
            (String.isNotBlank(orderBy) ? orderBy : ''),
			new Map<String,Object> {
				'value' => value
			},
			AccessLevel.SYSTEM_MODE
        );
    }

    public static SObject getRecord(Id recordId) {
        DescribeSObjectResult objDesc = recordId.getSObjectType().getDescribe();
        return Database.query(
            'SELECT ' +
                String.join(new List<String>(objDesc.fields.getMap().keySet()), ',') +
            ' FROM ' +
                objDesc.getName() + ' WHERE Id = :recordId'
        );
    }
}