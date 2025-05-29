/**
 * @description  : 
 * @group        : 
**/
@IsTest
public with sharing class OM_LoggerTest {
    
    public static final String USERNAME = 'testuser@omegatext.com.logger';
    public static final String USERNAME_NOTSETTINGS = 'testuser@omegatext.com.logger.nosetttings';

    public static User setup() {
        Profile admin = [SELECT ID From Profile WHERE PermissionsModifyAllData = true LIMIT 1];
        PermissionSet loggerPS = [SELECT Id FROM PermissionSet WHERE Name = 'OM_LoggerPermission' LIMIT 1];
        
        User testUser = new User(
            Username = USERNAME,
            ProfileId = admin.Id,
            FirstName = 'test',
            LastName = 'user test',
            Email = 'testusermail@omegatest.com',
            Alias = 'testuser', 
            TimeZoneSidKey = 'Europe/Paris', 
            LocaleSidKey = 'en_US', 
            EmailEncodingKey = 'ISO-8859-1', 
            LanguageLocaleKey = 'en_US'
        );

        insert testUser;

        User testUserNoSettings = new User(
            Username = USERNAME_NOTSETTINGS,
            ProfileId = admin.Id,
            FirstName = 'test',
            LastName = 'user test',
            Email = 'testuserNoSettingsmail@omegatest.com',
            Alias = 'usernsts', 
            TimeZoneSidKey = 'Europe/Paris', 
            LocaleSidKey = 'en_US', 
            EmailEncodingKey = 'ISO-8859-1', 
            LanguageLocaleKey = 'en_US'
        );

        insert testUserNoSettings;

        // Assign permission set to both users
        insert new List<PermissionSetAssignment> {
            new PermissionSetAssignment(AssigneeId = testUser.Id, PermissionSetId = loggerPS.Id),
            new PermissionSetAssignment(AssigneeId = testUserNoSettings.Id, PermissionSetId = loggerPS.Id)
        };

        System.runAs(testUser) {
            // Insert custom setting for the fist user
            insert new OM_LoggerSettings__c(
                Name = 'Test custom setting',
                DumpLimits__c = true,
                ValidUntil__c = Datetime.now() + 36000,
                SetupOwnerId = testuser.Id
            );
    
    
            List<Account> accs = new List<Account> {
                new Account(Name = 'test account 1'),
                new Account(Name = 'test account 2')
            };
            insert accs;
        }

        return testUser;
    }

    @TestSetup
    static void makeData(){
        setup();
    }

    @isTest
    public static void testLoggingWithSettings() {
        User userWithSettings = [SELECT ID FROM User WHERE Username = :USERNAME LIMIT 1];
        System.runAs(userWithSettings) {

            OM_Logger.info('This is a log');
            OM_Logger.error('This is another log');
            OM_Logger.save();
    
            List<OM_Log__c> logs = [SELECT Id, LimitDump__c FROM OM_Log__c];
            System.assertEquals(2, logs.size(), '2 logs should be created');
        }
    }

    @isTest
    public static void testLoggingWithSettingsAndPlatformEvents() {
        User userWithSettings = [SELECT ID FROM User WHERE Username = :USERNAME LIMIT 1];
        System.runAs(userWithSettings) {

            Test.startTest();
            OM_Logger.info('This is a log');
            OM_Logger.error('This is another log');
            OM_Logger.publish();
            Test.stopTest();
    
            List<OM_Log__c> logs = [SELECT Id, LimitDump__c FROM OM_Log__c];
            System.assertEquals(2, logs.size(), '2 logs should be created via Platform event');
        }
    }

    @isTest
    public static void testLoggingWithSettingsOverride() {
        User userWithSettings = [SELECT ID FROM User WHERE Username = :USERNAME LIMIT 1];
        System.runAs(userWithSettings) {

            // Even with settings enabled via custom settings,
            // calling disable() should not allow logs to be created
            OM_Logger.disable();
            OM_Logger.info('This is a log');
            OM_Logger.error('This is another log');
            OM_Logger.save();
            List<OM_Log__c> nologs = [SELECT Id, LimitDump__c FROM OM_Log__c];
            System.assertEquals(0, nologs.size(), 'No logs should be created when is disabled');

            // Re-enable to allow logging and the disable
            // limits dumpiong. The field should not be populated
            // Aloso cover serializable-object methods
            OM_Logger.enable();
            OM_Logger.disableLimits();
            OM_Logger.info(new Map<String, String> { 'info' => 'test' });
            OM_Logger.error(new Map<String, String> { 'error' => 'test' });
            OM_Logger.save();
            List<OM_Log__c> logs = [SELECT Id, LimitDump__c FROM OM_Log__c];
            System.assertEquals(2, logs.size(), '2 logs should be created');
            System.assertEquals(null, logs.get(0).LimitDump__c, 'Limits should NOT be dumped in the field');
        }
    }

    @isTest
    public static void testLoggingWithoutSettings() {
        User userWithoutSettings = [SELECT ID FROM User WHERE Username = :USERNAME_NOTSETTINGS LIMIT 1];
        System.runAs(userWithoutSettings) {
            // With the user without settings linked
            // no logs shoiuld be created, only System.debug call
            // are processed
            OM_Logger.info('This is a log');
            OM_Logger.error('This is another log');
            OM_Logger.save();
    
            List<OM_Log__c> logs = [SELECT Id, LimitDump__c FROM OM_Log__c];
            System.assertEquals(0, logs.size(), 'No logs should be created');


            // Now we override settings using enable() programatically
            // and should override event no existing settings
            // Also, if the enable limits dumpoing, the field should be populated
            OM_Logger.enable();
            OM_Logger.enableLimits();
            OM_Logger.info('This is a log - enabled');
            OM_Logger.info('This is another log - enabled');
            OM_Logger.save();
    
            List<OM_Log__c> logs2 = [SELECT Id, LimitDump__c FROM OM_Log__c];
            System.assertEquals(2, logs2.size(), '2 logs should be created after enabling');
            System.assertNotEquals(null, logs2.get(0).LimitDump__c, 'Limits should be dumped in the field');

        }
    }

    @isTest
    public static void processSaveResultTest() {
        User userWithSettings = [SELECT ID FROM User WHERE Username = :USERNAME LIMIT 1];
        System.runAs(userWithSettings) {

            Test.startTest();
            OM_Logger.processSaveResult(Database.insert(new List<Account>{new Account()}, false));
            OM_Logger.save();
            Test.stopTest();

            List<OM_Log__c> logs2 = [SELECT Id, LimitDump__c FROM OM_Log__c];
            Assert.areEqual(1, logs2.size(), '1 log should be created');
        }
    }

    @isTest
    public static void processUpsertResultTest() {
        User userWithSettings = [SELECT ID FROM User WHERE Username = :USERNAME LIMIT 1];
        System.runAs(userWithSettings) {

            Test.startTest();
            OM_Logger.processUpsertResult(Database.upsert(new List<Account>{new Account()}, false));
            OM_Logger.save();
            Test.stopTest();

            List<OM_Log__c> logs2 = [SELECT Id, LimitDump__c FROM OM_Log__c];
            Assert.areEqual(1, logs2.size(), '1 log should be created');
        }
    }

    @isTest
    public static void processDeleteResultTest() {
        User userWithSettings = [SELECT ID FROM User WHERE Username = :USERNAME LIMIT 1];
        System.runAs(userWithSettings) {

            Test.startTest();
            OM_Logger.info('This is a log');
            OM_Logger.save();

            OM_Logger.processDeleteResult(Database.delete([SELECT Id FROM OM_Log__c], false));
            Test.stopTest();

            List<OM_Log__c> logs2 = [SELECT Id, LimitDump__c FROM OM_Log__c];
            Assert.areEqual(0, logs2.size(), '0 log should be created');
        }
    }
}