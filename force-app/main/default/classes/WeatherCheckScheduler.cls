global class WeatherCheckScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new WeatherCheckBatch(), 50);
    }
}