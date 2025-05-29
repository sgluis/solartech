public with sharing class installationContractTriggerHandler {
    public static void handleTasks(List<InstallationContract__c> newList, Map<Id, InstallationContract__c> oldMap) {
        Date today = Date.today();
        Date cutoff = today.addDays(10);
        List<InstallationContract__c> toProcess = new List<InstallationContract__c>();
        
        for (InstallationContract__c c : newList) {
            InstallationContract__c old = oldMap != null ? oldMap.get(c.Id) : null;
            Boolean isNew = old == null;
            Boolean dateChanged = !isNew && c.FechaDeInstalacion__c != old.FechaDeInstalacion__c;
            
            if (c.FechaDeInstalacion__c != null && c.FechaDeInstalacion__c >= today && c.FechaDeInstalacion__c <= cutoff && (isNew || dateChanged)) {
                toProcess.add(c);
            }
        }
        if (toProcess.isEmpty()) return;
        
        Set<Id> contractIds = new Set<Id>();
        for (InstallationContract__c c : toProcess) contractIds.add(c.Id);
        Map<Id, Set<String>> existingSubjects = new Map<Id, Set<String>>();
        for (Task t : [SELECT WhatId, Subject FROM Task WHERE WhatId IN :contractIds AND Subject LIKE 'Instalación%']) {
            if (!existingSubjects.containsKey(t.WhatId)) {
                existingSubjects.put(t.WhatId, new Set<String>());
            }
            existingSubjects.get(t.WhatId).add(t.Subject);
        }
        
        List<Task> tasksToInsert = new List<Task>();
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (InstallationContract__c c : toProcess) {
            String subj = 'Instalación: ' + c.Name + ' el ' + c.FechaDeInstalacion__c.format();
            if (existingSubjects.containsKey(c.Id)
                && existingSubjects.get(c.Id).contains(subj)) {
                continue;
            }
            
            if (c.Tecnico__c != null) {
                Task t = new Task(
                    WhatId      = c.Id,
                    OwnerId     = c.Tecnico__c,
                    Subject     = subj,
                    ActivityDate= c.FechaDeInstalacion__c,
                    WhoId = c.Cliente__r.Name,
                    Status      = 'Not Started',
                    Priority    = 'Normal'
                );
                tasksToInsert.add(t);
            } else if (c.Supervisor__c != null) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[]{ c.Supervisor__r.Email });
                mail.setSubject('Alerta: Sin técnico asignado en contrato ' + c.Name);
                mail.setPlainTextBody(
                    'Hola,\n\n'
                    + 'El contrato de instalación "' + c.Name + '" con fecha '
                    + c.FechaDeInstalacion__c.format()
                    + ' no tiene técnico asignado.\n'
                    + 'Por favor, asigna un técnico lo antes posible.\n\n'
                    + 'Saludos,\nSalesforce Automation'
                );
                mails.add(mail);
            }
        }
        
        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }
        if (!mails.isEmpty()) {
            Messaging.sendEmail(mails);
        }
    }
}