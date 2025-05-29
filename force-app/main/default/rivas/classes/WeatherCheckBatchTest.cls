@IsTest
public class WeatherCheckBatchTest {

    @TestSetup
    static void setupCommonData() {
        Contact contacto = new Contact(LastName='Contacto Test', Email='test@ejemplo.com');
        insert contacto;
        insert new InstallationContract__c(
            Cliente__c = contacto.Id,
            FechaDeInstalacion__c = Date.today().addDays(3),
            Address__City__s = 'Valencia'
        );
    }

    @IsTest
    static void testBatchWithBadWeather() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Date fechaInst = Date.today().addDays(2);
        List<InstallationContract__c> insts = new List<InstallationContract__c>{
            new InstallationContract__c(
                Cliente__c = c.Id,
                FechaDeInstalacion__c = fechaInst,
                Address__City__s = 'Madrid'
            ),
            new InstallationContract__c(
                Cliente__c = c.Id,
                FechaDeInstalacion__c = fechaInst,
                Address__City__s = 'Barcelona'
            )
        };
        insert insts;

        List<Task> tareasPrevias = new List<Task>();
        for (InstallationContract__c ic : insts) {
            tareasPrevias.add(new Task(
                WhatId = ic.Id,
                Subject = 'Instalación: ' + ic.Address__City__s,
                ActivityDate = fechaInst
            ));
        }
        insert tareasPrevias;

        Test.setMock(HttpCalloutMock.class, new WeatherApiMocks.BadWeatherMock());
        Test.startTest();
        Database.executeBatch(new WeatherCheckBatch(), 200);
        Test.stopTest();

        Date esperado = fechaInst.addDays(1);
        for (InstallationContract__c ic : [SELECT FechaDeInstalacion__c FROM InstallationContract__c WHERE Id IN :insts]) {
            System.assertEquals(esperado, ic.FechaDeInstalacion__c,'La instalación debe moverse un día por mal tiempo');
        }

        // System.assertEquals(1,Limits.getEmailInvocations(),'Debe invocar una única llamada a sendEmail (que internamente envía 2 mensajes)');

        List<Task> tareasActualizadas = [SELECT WhatId, ActivityDate FROM Task WHERE WhatId IN :insts];
        System.assertEquals(2,tareasActualizadas.size(),'Debe seguir habiendo exactamente 2 tareas');

        for (Task t : tareasActualizadas) {
            System.assertEquals(esperado,t.ActivityDate,'Cada tarea debe haberse movido un día');
        }
    }

    @IsTest 
    static void testBatchWithGoodWeather() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Date fechaInst = Date.today().addDays(2);
        List<InstallationContract__c> lista = new List<InstallationContract__c>();
        for (String city : new List<String>{'Madrid','Barcelona'}) {
            lista.add(new InstallationContract__c(
                Cliente__c = c.Id,
                FechaDeInstalacion__c = fechaInst,
                Address__City__s = city
            ));
        }
        insert lista;

        Test.setMock(HttpCalloutMock.class, new WeatherApiMocks.GoodWeatherMock());
        Test.startTest();
        Database.executeBatch(new WeatherCheckBatch(), 200);
        Test.stopTest();

        for (InstallationContract__c ic : [SELECT FechaDeInstalacion__c FROM InstallationContract__c WHERE Address__City__s IN ('Madrid','Barcelona')]) {
            System.assertEquals(fechaInst, ic.FechaDeInstalacion__c);
        }
        System.assertEquals(0, Limits.getEmailInvocations());
        System.assertEquals(0,[SELECT count() FROM Task WHERE Subject LIKE 'Instalación:%']
        );
    }

    @IsTest 
    static void testBatchWithApiError() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Date fechaInst = Date.today().addDays(2);
        insert new InstallationContract__c(Cliente__c=c.Id, FechaDeInstalacion__c=fechaInst, Address__City__s='Madrid');
        insert new InstallationContract__c(Cliente__c=c.Id, FechaDeInstalacion__c=fechaInst, Address__City__s='Barcelona');

        Test.setMock(HttpCalloutMock.class, new WeatherApiMocks.ApiErrorMock());
        Test.startTest();
        Database.executeBatch(new WeatherCheckBatch(), 200);
        Test.stopTest();

        for (InstallationContract__c ic : [SELECT FechaDeInstalacion__c FROM InstallationContract__c WHERE Address__City__s IN ('Madrid','Barcelona')]) {
            System.assertEquals(fechaInst, ic.FechaDeInstalacion__c);
        }
        System.assertEquals(0, Limits.getEmailInvocations());
        System.assertEquals(0,[SELECT count() FROM Task WHERE Subject LIKE 'Instalación:%']);
    }

    @IsTest 
    static void testBatchQueryFilter() {
        WeatherCheckBatch batch = new WeatherCheckBatch();
        Database.QueryLocator ql = batch.start(null);
        String q = ql.getQuery().toLowerCase();
        System.assert(q.contains('fechadeinstalacion__c'));
        System.assert(q.contains('= :'));
    }

    @IsTest 
    static void testWindSpeedAboveThreshold() {
        Test.setMock(HttpCalloutMock.class, new WeatherApiMocks.WindAboveMock());
        Contact c = new Contact(LastName='C', Email='x@x.com');
        insert c;
        InstallationContract__c ic = new InstallationContract__c(
            Cliente__c = c.Id,
            FechaDeInstalacion__c = Date.today().addDays(2),
            Address__City__s = 'Sevilla'
        );
        insert ic;

        Test.startTest();
        Database.executeBatch(new WeatherCheckBatch(), 200);
        Test.stopTest();

        ic = [SELECT FechaDeInstalacion__c FROM InstallationContract__c WHERE Id = :ic.Id];
        System.assertEquals(Date.today().addDays(3), ic.FechaDeInstalacion__c);
    }

    @IsTest 
    static void testWindSpeedExactlyBoundary() {
        Test.setMock(HttpCalloutMock.class, new WeatherApiMocks.WindBoundaryMock());
        Contact c = new Contact(LastName='C2', Email='y@y.com');
        insert c;
        InstallationContract__c ic = new InstallationContract__c(
            Cliente__c = c.Id,
            FechaDeInstalacion__c = Date.today().addDays(2),
            Address__City__s = 'Sevilla'
        );
        insert ic;

        Test.startTest();
        Database.executeBatch(new WeatherCheckBatch(), 200);
        Test.stopTest();

        ic = [SELECT FechaDeInstalacion__c FROM InstallationContract__c WHERE Id = :ic.Id];
        System.assertEquals(Date.today().addDays(2), ic.FechaDeInstalacion__c);
    }

    @IsTest 
    static void testWeatherIdBoundary() {
        Test.setMock(HttpCalloutMock.class, new WeatherApiMocks.WeatherId200Mock());
        Contact c = new Contact(LastName='C3', Email='z@z.com');
        insert c;
        InstallationContract__c ic = new InstallationContract__c(
            Cliente__c = c.Id,
            FechaDeInstalacion__c = Date.today().addDays(2),
            Address__City__s = 'Bilbao'
        );
        insert ic;

        Test.startTest();
        Database.executeBatch(new WeatherCheckBatch(), 200);
        Test.stopTest();

        ic = [SELECT FechaDeInstalacion__c FROM InstallationContract__c WHERE Id = :ic.Id];
        System.assertEquals(Date.today().addDays(3), ic.FechaDeInstalacion__c);
    }

    @IsTest 
    static void testEmptyScopeDoesNothing() {
        Test.startTest();
        new WeatherCheckBatch().execute(null, new List<InstallationContract__c>());
        Test.stopTest();
        System.assertEquals(0, Limits.getEmailInvocations());
        System.assertEquals(0, [SELECT count() FROM Task]);
    }
}