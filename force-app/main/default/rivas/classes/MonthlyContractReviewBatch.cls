global with sharing class MonthlyContractReviewBatch implements Database.Batchable<SObject> {
    global Database.QueryLocator start(Database.BatchableContext bc) {
        Date cutoff = Date.today().addDays(-30);
        return Database.getQueryLocator([SELECT Id, Estado__c FROM InstallationContract__c WHERE Estado__c = 'En proceso' AND LastModifiedDate <= :DateTime.newInstance(cutoff, Time.newInstance(0,0,0,0))]);
    }
    
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<InstallationContract__c> toUpdate = new List<InstallationContract__c>();

        for (InstallationContract__c c : (List<InstallationContract__c>) scope) {
            c.Estado__c = 'Pendientes de revisión';
            toUpdate.add(c);
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
    
    global void finish(Database.BatchableContext bc) {
    }
}
/*
MonthlyContractReviewBatch batch = new MonthlyContractReviewBatch();
Database.executeBatch(batch, 200);
*/