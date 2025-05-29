/**
 * @description       Deletes old log records (OM_Log__c) in batches.
 * @author            David López <sdlopez@omegacrmconsulting.com>
 * @group             Batches
 * @test class        OM_LoggerDeleteBatchTest
 * @last modified on  01-05-2024
 * @last modified by  David López <sdlopez@omegacrmconsulting.com>  
 * Modifications Log
 * Ver   Date         Author                                         Modification
 * 1.0   01-05-2024   David López <sdlopez@omegacrmconsulting.com>   Initial Version
 */
global with sharing class OM_LoggerDeleteBatch implements Database.Batchable<SObject>, Schedulable {

	/**
	 * The query that will be executed to retrieve the logs to delete.
	 */
	private String query;

	/**
	 * Number of days to look for old logs.
	 */
	global Integer numDays = 15;

	/**
	 * The number of records to process in each batch.
	 */
	global Integer scopeSize = 200;

	/**
	 * Initializes the query to use in the delete operation.
	 */
	global OM_LoggerDeleteBatch() {
		query = 'SELECT Id FROM OM_Log__c WHERE CreatedDate < LAST_N_DAYS:' + numDays;
	}

	/**
	 * @description Returns a query locator for the execution of the query defined in the constructor.
	 *
	 * @param bc Context of the batch operation
	 * @return Query locator for the log records query
	 */
	global Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(query);
	}

	/**
	 * @description Deletes the records in the `scope` list.
	 *
	 * @param bc      Context of the batch operation
	 * @param scope   List of records to delete
	 */
	global void execute(Database.BatchableContext bc, List<SObject> scope) {
		Database.delete(scope, false, System.AccessLevel.SYSTEM_MODE);
	}

	/**
	 * @description Finalizes the batch execution. Nothing to do here.
	 *
	 * @param bc Context of the batch operation
	 */
	global void finish(Database.BatchableContext bc) {}

	/**
	 * @description Executes the batch operation defined in this class.
	 *
	 * @param sc Context of the schedulable class
	 */
	global void execute(SchedulableContext sc) {
		Database.executeBatch(this ?? new OM_LoggerDeleteBatch(), this?.scopeSize ?? scopeSize);
	}
}