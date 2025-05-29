global with sharing class MonthlyContractReviewScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new MonthlyContractReviewBatch(), 200);
    }
}