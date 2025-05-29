/**
 * @description  Main logger class 
 * @group        Logger 
**/
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class OM_Logger {

    global enum Levels {
        INFO,
        ERROR,
        SUCCESS,
        WARN
    }

    // The settings to apply for the current user
    static OM_LoggerSettings__c settings = OM_LoggerSettings__c.getInstance(userInfo.getUserId());

    // The in-memory list of logs to insert
    static List<OM_Log__c> logs = new List<OM_Log__c>();

    // Whether the logging is enabled or not
    static Boolean isEnabled = (settings != null && Datetime.now() < settings.ValidUntil__c);

    // Whether the limits should be dumped for each log
    static Boolean hasToDumpLimits = settings?.DumpLimits__c;

    /**
     * @description Enables the logging, overriding the settings retrieved
     */
    public static void enable() {
        isEnabled = true;
    }

    /**
     * @description Disables the logging, overriding the settings retrieved
     */
    public static void disable() {
        isEnabled = false;
    }

    /**
     * @description Enables the limits dumnping, overriding the settings retrieved
     */
    public static void enableLimits() {
        hasToDumpLimits = true;
    }

    /**
     * @description Disables the limits dumnping, overriding the settings retrieved
     */
    public static void disableLimits() {
        hasToDumpLimits = false;
    }
    
    /**
     * @description Logs a message with INFO level
     * @param  message The message to log
     */
    public static void info(String message) {
        addLog(Levels.INFO, message, null);
    }

    /**
     * @description Logs a message with INFO level
     * @param  message The serializable object to log
     */
    public static void info(Object message) {
        addLog(Levels.INFO, JSON.serializePretty(message), null);
    }

    /**
     * @description Logs a message with INFO level and the class and method indicated
     * @param  message      The message to log
     * @param  classMethod  Map with key:class and value:method_name
     */
    public static void info(String message, Map<String, String> classMethod) {
        addLog(Levels.INFO, message, classMethod);
    }

    /**
     * @description Logs a message with INFO level and the class and method indicated
     * @param  message      The serializable object to log
     * @param  classMethod  Map with key:class and value:method_name
     */
    public static void info(Object message, Map<String, String> classMethod) {
        addLog(Levels.INFO, JSON.serializePretty(message), classMethod);
    }

    /**
     * @description Logs a message with ERROR level
     * @param  message The message to log
     */
    public static void error(String message) {
        addLog(Levels.ERROR, message, null);
    }

    /**
     * @description Logs a message with ERROR level
     * @param  message The serializable object to log
     */
    public static void error(Object message) {
        addLog(Levels.ERROR, JSON.serializePretty(message), null);
    }

    /**
     * @description Logs a message with ERROR level
     * @param  message The message to log
     */
    public static void error(String message, Map<String, String> classMethod) {
        addLog(Levels.ERROR, message, classMethod);
    }

    /**
     * @description Logs a message with ERROR level
     * @param  message The serializable object to log
     */
    public static void error(Object message, Map<String, String> classMethod) {
        addLog(Levels.ERROR, JSON.serializePretty(message), classMethod);
    }

    /**
     * @description Saves generated logs using DML
     */
    public static void save() {
        saveLogs(logs);
        logs = new List<OM_Log__c>();

    }

    /**
     * @description Saves the logs records en database
     * @param  logsToSave The collection to save
     */
    public static void saveLogs(List<OM_Log__c> logsToSave) {
        if(!logsToSave.isEmpty()) {
            OM_LogGroup__c lgroup = new OM_LogGroup__c(
                User__c = logsToSave.get(0).User__c,
                RequestId__c = logsToSave.get(0).RequestId__c,
                RequestType__c = logsToSave.get(0).RequestType__c,
                Timestamp__c = logsToSave.get(0).Timestamp__c
            );

            insert lgroup; // NOPMD

            for(OM_Log__c log : logsToSave) {
                log.Group__c = lgroup.Id;
            }
            insert Security.stripInaccessible(AccessType.CREATABLE, logsToSave).getRecords();
        }
    }

    /**
     * @description Publish the logs as Platform events
     */
    public static void publish() {
        if(!logs.isEmpty()) {
            List<OM_LogEvent__e> events = recordsToEvents();
            EventBus.publish(events);
            logs = new List<OM_Log__c>();
        }
    }

    private static void addLog(Levels level, String message, Map<String, String> classMethod) {

        System.debug(LoggingLevel.ERROR, message);

        if(!isEnabled) { 
            return;
        }
        classMethod = classMethod ?? getClassAndMethod();
        Request reqInfo = Request.getCurrent();
        OM_Log__c record = new OM_Log__c(
            User__c = UserInfo.getUserId(),
            Level__c = String.valueOf(level),
            Message__c = message,
            Class__c = classMethod.get('class'),
            Method__c  = classMethod.get('method'),
            RequestId__c = reqInfo.getRequestId(),
            RequestType__c = String.valueOf(reqInfo.getQuiddity()),
            Timestamp__c = Datetime.now()
        );

        if(hasToDumpLimits) {
            record.LimitDump__c = JSON.serializePretty(new Map<String, Object>{
                'AggregateQueries' => Limits.getAggregateQueries(),
                'Callouts' => Limits.getCallouts(),
                'CpuTime' => Limits.getCpuTime(),
                'DmlRows' => Limits.getDmlRows(),
                'DmlStatements' => Limits.getDmlStatements(),
                'EmailInvocations' => Limits.getEmailInvocations(),
                'FutureCalls' => Limits.getFutureCalls(),
                'HeapSize' => Limits.getHeapSize(),
                'QueryLocatorRows' => Limits.getQueryLocatorRows(),
                'Queries' => Limits.getQueries(),
                'QueryRows' => Limits.getQueryRows(),
                'QueueableJobs' => Limits.getQueueableJobs(),
                'SoslQueries' => Limits.getSoslQueries()
            });
        }
        logs.add(record);
    }

    private static List<OM_LogEvent__e> recordsToEvents() {
        List<OM_LogEvent__e> res = new List<Om_LogEvent__e>();
        for(OM_Log__c obj : logs) {
            res.add(new OM_LogEvent__e(
                User__c = obj.User__c,
                Level__c = obj.Level__c,
                Message__c = obj.Message__c,
                Class__c =  obj.Class__c,
                Method__c = obj.Method__c,
                RequestId__c = obj.RequestId__c,
                RequestType__c = obj.RequestType__c,
                LimitDump__c = obj.LimitDump__c,
                Timestamp__c = obj.Timestamp__c
            ));
        }
        return res;
    }

    /**
     * @description Converts platform event object to regular objects
     * @param  events The events to transform
     * @return        The transformed list
     */
    public static List<OM_Log__c> eventsToRecords(List<OM_LogEvent__e> events) {
        List<OM_Log__c> res = new List<OM_Log__c>();
        for(OM_LogEvent__e obj : events) {
            res.add(new OM_Log__c(
                User__c = obj.User__c,
                Level__c = obj.Level__c,
                Message__c = obj.Message__c,
                Class__c =  obj.Class__c,
                Method__c = obj.Method__c,
                RequestId__c = obj.RequestId__c,
                RequestType__c = obj.RequestType__c,
                LimitDump__c = obj.LimitDump__c,
                Timestamp__c = obj.Timestamp__c
            ));
        }
        return res;
    }

    private static Map<String, String> getClassAndMethod() {
        // remove addLog and previous Logger call
        List<String> stackTraces = new DmlException()
            .getStackTraceString()
            .substringAfter('\n')
            .split('\n');
        
        stackTraces.remove(0);
        stackTraces.remove(0);
        
        String stackTrace = String.join(stackTraces, '\n');

        System.debug(LoggingLevel.ERROR, stackTrace);
        return new Map<String, String> {
            'class' => stackTrace.startsWith('Class.') 
                ? stackTrace.substringAfter('Class.').substringBefore(':').substringBeforeLast('.')
                : stackTrace.substringBefore(':').substringBeforeLast('.'),
            'method' => stackTrace.substringBefore(':').substringAfterLast('.')
        };
    }

    /**
     * @description Process List<Database.SaveResult> and generate logs for error ones
     * @param  results List<Database.SaveResult> to process
     */
    public static void processSaveResult(List<Database.SaveResult> results) {
        processSaveResult(results, null);
    }
    
    /**
     * @description Process List<Database.SaveResult> and generate logs for error ones
     * @param  results     List<Database.SaveResult> to process
     * @param  classMethod classMethod  Map with key:class and value:method_name
     */
    public static void processSaveResult(List<Database.SaveResult> results, Map<String, String> classMethod) {

        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                error(new Map<String, Object>{ 'Id: ' => sr.getId(), 'Errors: ' => sr.getErrors() }, classMethod);
            }
        }
    }

    /**
     * @description Process List<Database.UpsertResult> and generate logs for error ones
     * @param  results     List<Database.UpsertResult> to process
     */
    public static void processUpsertResult(List<Database.UpsertResult> results) {
        processUpsertResult(results, null);
    }

    /**
     * @description Process List<Database.UpsertResult> and generate logs for error ones
     * @param  results     List<Database.UpsertResult> to process
     * @param  classMethod classMethod  Map with key:class and value:method_name
     */
    public static void processUpsertResult(List<Database.UpsertResult> results, Map<String, String> classMethod) {

        for (Database.UpsertResult sr : results) {
            if (!sr.isSuccess()) {
                error(new Map<String, Object>{ 'Id: ' => sr.getId(), 'Errors: ' => sr.getErrors() }, classMethod);
            }
        }
    }

    /**
     * @description Process List<Database.DeleteResult> and generate logs for error ones
     * @param  results     List<Database.DeleteResult> to process
     */
    public static void processDeleteResult(List<Database.DeleteResult> results) {
        processDeleteResult(results, null);
    }

    /**
     * @description Process List<Database.DeleteResult> and generate logs for error ones
     * @param  results     List<Database.DeleteResult> to process
     * @param  classMethod classMethod  Map with key:class and value:method_name
     */
    public static void processDeleteResult(List<Database.DeleteResult> results, Map<String, String> classMethod) {

        for (Database.DeleteResult sr : results) {
            if (!sr.isSuccess()) {
                error(new Map<String, Object>{ 'Id: ' => sr.getId(), 'Errors: ' => sr.getErrors() }, classMethod);
            }
        }
    }
}