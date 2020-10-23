public class litmosCreateUser {
	//constant for configuration info
    static final Litmos__Configuration__c config = [SELECT Litmos__Api_Key__c,Litmos__API_End_Point__c FROM Litmos__Configuration__c WHERE isDeleted = false AND Litmos__Sync_Active__c = true LIMIT 1];
	@future(callout=true)
    public static void createUser(Set<Id> ids) {
        System.debug('ids: ' + ids);
        //get list of users
        List<User> users = [SELECT Id,FirstName,LastName,Email,ManagerId,Manager.Litmos__LitmosUserId__c,Litmos__LitmosUserId__c,Country,Title FROM User WHERE Id IN :ids];
        System.debug('users: ' + users);
    	
        //get map of managers
       	Set<Id> mgrIds = new Set<Id>();
        List<User> successUsers = new List<User>();
        List<User> failedUsers = new List<User>();
        Map<String,String> errors = new Map<String,String>();
        for(User u : users) {
            if(u.ManagerId!= null) {
                mgrIds.add(u.ManagerId);
            } else {
                failedUsers.add(u);
                errors.put(u.Id, 'Litmos Sync Error: No Manager Id');
            }
        }
        Map<Id,User> managers = new Map<Id,User>([SELECT Litmos__LitmosUserId__c FROM User WHERE Id IN :mgrIds]);

		//create HttpRequest and set endpoint, method, and header        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(config.Litmos__API_End_Point__c + 'users?source=LitmosCallout');
        req.setMethod('POST');
        req.setHeader('apikey', config.Litmos__API_Key__c);
        req.setHeader('content-type','application/json');
        
        //generate json body
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        for(User u : users) {
            if(managers.get(u.ManagerId).Litmos__LitmosUserId__c == null) {
                failedUsers.add(u);
                errors.put(u.Id, 'Manager missing Litmos Id');
            } else {
                gen.writeStringField('UserName',u.Email);
                gen.writeStringField('FirstName', u.FirstName);
                gen.writeStringField('LastName',u.LastName);
                gen.writeStringField('Email',u.Email);
                gen.writeStringField('AccessLevel','Learner');
                gen.writeBooleanField('DisableMessages',false);
                gen.writeBooleanField('Active',true);
                gen.writeBooleanField('SkipFirstLogin',true);
                gen.writeStringField('Country',u.Country);
                gen.writeStringField('JobTitle',u.Title);
                gen.writeStringField('ManagerId',u.Manager.Litmos__LitmosUserId__c);
                gen.writeStringField('Brand','Employee');
                gen.writeStringField('SalesforceId',u.Id);
                successUsers.add(u);
            }
        }
        gen.writeEndObject();
        String jsonBody = gen.getAsString();
        System.debug('jsonBody: ' + jsonBody);
        //finalize and send request
        req.setBody(jsonBody);
        Http http = new Http();
        //HttpResponse response = http.send(req);

        //manage response
        //System.debug('response: ' + response);
        
        //add to log
        if(successUsers.size() > 0) {
            litmosSyncLogs.logUserSuccess(successUsers);
        }
        //if(response.getStatusCode() != 201) {
          //  System.debug('bad request');
        //}
        if(failedUsers.size() > 0) {
            litmosSyncLogs.logUserErrors(failedUsers, errors);
        }
        
    }    

}