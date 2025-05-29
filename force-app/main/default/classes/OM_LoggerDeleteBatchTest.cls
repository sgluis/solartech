/**
 * @description       Test class for OM_LoggerDeleteBatch
 * @author            David López <sdlopez@omegacrmconsulting.com>
 * @group             Test
 * @last modified on  01-05-2024
 * @last modified by  David López <sdlopez@omegacrmconsulting.com> 
 * Modifications Log
 * Ver   Date         Author                                         Modification
 * 1.0   01-05-2024   David López <sdlopez@omegacrmconsulting.com>   Initial Version
**/
@isTest
public class OM_LoggerDeleteBatchTest {

    @TestSetup
    static void makeData(){

        User testUser = OM_LoggerTest.setup();

        System.runAs(testUser) {
            OM_Log__c log = new OM_Log__c();
            insert log;

            Test.setCreatedDate(log.Id, Date.today().addDays(-16));
        }
    }
    
    @isTest
    static void omLoggerDeleteBatchTest() {

        User testUser = [SELECT ID FROM User WHERE Username = :OM_LoggerTest.USERNAME LIMIT 1];
        System.runAs(testUser) {
            Test.startTest();

            Database.executeBatch(new OM_LoggerDeleteBatch());

            Test.stopTest();

            List<OM_Log__c> logs = [SELECT Id FROM OM_Log__c];
            Assert.areEqual(0, logs.size(), '0 log should remain');
        }
    }

    @isTest
    static void omLoggerScheduleBatchTest() {
        User testUser = [SELECT ID FROM User WHERE Username = :OM_LoggerTest.USERNAME LIMIT 1];
        System.runAs(testUser) {
            Test.startTest();

            Datetime dt = Datetime.now();
            String cronExp = '0 '+ dt.minute() + ' * ' + dt.day() + ' ' + dt.month() + ' ? ' + dt.year();
            String idSched = System.schedule('OM_LoggerDeleteBatchSchedule_TEST', cronExp, new OM_LoggerDeleteBatch());

            Test.stopTest();

            List<OM_Log__c> logs = [SELECT Id FROM OM_Log__c];
            Assert.areNotEqual(null, idSched, 'Batch should be scheduled');
        }
    }
}