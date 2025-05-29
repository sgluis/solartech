public with sharing class WeatherCheckBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
    private String apiKey;
    private String urlBase;

    public WeatherCheckBatch() {
        TiempoAPIConfig__mdt cfg = [SELECT APIKey__c, UrlBase__c FROM TiempoAPIConfig__mdt LIMIT 1];
        apiKey  = cfg.APIKey__c;
        urlBase = cfg.UrlBase__c;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date target = Date.today().addDays(2);
        return Database.getQueryLocator([SELECT Id, FechaDeInstalacion__c, Cliente__r.Email, Address__City__s FROM InstallationContract__c WHERE FechaDeInstalacion__c = :target]);
    }

    public void execute(Database.BatchableContext bc, List<InstallationContract__c> scope) {
        List<InstallationContract__c> toUpdate = new List<InstallationContract__c>();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Task> tasksToUpdate = new List<Task>();

        for (InstallationContract__c inst : scope) {
            String ciudad = EncodingUtil.urlEncode(inst.Address__City__s, 'UTF-8');

            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(urlBase + '?q='+ciudad+',es'+ '&appid=' + apiKey+ '&units=metric'+ '&lang=es');
            req.setMethod('GET');
            HttpResponse res = http.send(req);
            if (res.getStatusCode() != 200) {
                OM_Logger.error('Weather API Error: ' + res.getStatusCode() + ' – ' + res.getBody());
                OM_Logger.publish();
                continue;
            }

            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> lista = (List<Object>) parsed.get('list');

            Boolean badWeather = false;
            for (Object o : lista) {
                Map<String, Object> punto = (Map<String, Object>) o;
                Map<String, Object> principal = (Map<String, Object>) punto.get('main');
                Map<String, Object> viento   = (Map<String, Object>) punto.get('wind');
                List<Object> weatherArr = (List<Object>) punto.get('weather');
                Integer weatherId = (Integer)((Map<String,Object>)weatherArr[0]).get('id');
                Double  windSpeed = (Double) viento.get('speed');

                if (windSpeed > 10.0 || (weatherId >= 200 && weatherId < 700)) {
                    badWeather = true;
                    break;
                }
            }

            if (badWeather) {
                inst.FechaDeInstalacion__c = inst.FechaDeInstalacion__c.addDays(1);
                toUpdate.add(inst);

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[]{ inst.Cliente__r.Email });
                mail.setSubject('Reprogramación de su instalación');
                mail.setPlainTextBody(
                    'Hola,\n\n'
                    + 'Debido a previsión de mal tiempo en '+inst.Address__City__s+', hemos reprogramado su instalación para '
                    + inst.FechaDeInstalacion__c.format() + '.\n\n'
                    + 'Gracias por su comprensión.'
                );
                emails.add(mail);

                for (Task t : [SELECT Id, ActivityDate FROM Task WHERE WhatId = :inst.Id AND Subject LIKE 'Instalación:%']) {
                    t.ActivityDate = inst.FechaDeInstalacion__c;
                    tasksToUpdate.add(t);
                }

            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
            Messaging.sendEmail(emails);
             if (!tasksToUpdate.isEmpty()) {
            update tasksToUpdate;
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
    }
}
/*
WeatherCheckBatch batch = new WeatherCheckBatch();
Database.executeBatch(batch, 200);
*/