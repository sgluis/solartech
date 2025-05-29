trigger installationContractTrigger on InstallationContract__c (after insert, after update) {
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        installationContractTriggerHandler.handleTasks(Trigger.new, Trigger.oldMap);
    }
}