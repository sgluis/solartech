/**
 * @description  : 
 * @group        : 
**/
trigger OM_LogEventTrigger on OM_LogEvent__e (after insert) {
  List<OM_Log__c> logs = OM_Logger.eventsToRecords((List<OM_LogEvent__e>) Trigger.new);
  // insert Security.stripInaccessible(AccessType.CREATABLE, logs).getRecords();
  OM_Logger.saveLogs(logs);
}