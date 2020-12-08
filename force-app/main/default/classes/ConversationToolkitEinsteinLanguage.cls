public with sharing class ConversationToolkitEinsteinLanguage {
    
    @AuraEnabled
    public static void updateEinsteinInsightsOnCompletion(String channelType, String recordId){
        System.debug('Updating Einstein Insights ' + channelType + recordId);
        List<Einstein_Insight__c> eiList = new List<Einstein_Insight__c>();
        if (channelType == 'Voice'){
            eiList = [SELECT ID, Position__c, CreatedDate FROM Einstein_Insight__c WHERE Voice_Call__c =:recordId ORDER BY CreatedDate ASC];
        } else if (channelType == 'Chat'){
            eiList = [SELECT ID, Position__c, CreatedDate FROM Einstein_Insight__c WHERE Chat_Transcript__c =:recordId ORDER BY CreatedDate ASC];
        } else if (channelType == 'Messaging'){
            eiList = [SELECT ID, Position__c, CreatedDate FROM Einstein_Insight__c WHERE Messaging_Session__c =:recordId ORDER BY CreatedDate ASC];
        }
        System.debug('Updating Einstein Insights: List size' + eiList.size());
        if (eiList.size()>0){
            Integer percentage = 100/eiList.size();
            Integer currentPercentage = 0;
            System.debug('Updating Einstein Insights: Percentage ' + percentage);            
            for (Einstein_Insight__c ei : eiList){
                currentPercentage += percentage;
                ei.Position__c = currentPercentage;
            }
            update eiList;
        }
    }

    @AuraEnabled
    public static Einstein_Insight__c retrieveInsightOnHandoff(String channelType, String recordId){
        System.debug('Retrieving Last Einstein Insight ' + channelType + recordId);

        Einstein_Insight__c eiRecord = new Einstein_Insight__c();
        //default values
        eiRecord.Aggregated_Sentiment__c = 0;
        eiRecord.Sentiment__c = 'neutral'; // no intent
        eiRecord.Sentiment_Confidence__c = 0.0;
        eiRecord.Intent__c = ''; // no intent
        eiRecord.Intent_Confidence__c = 0.0;

        try{

            if (channelType == 'Voice'){
                eiRecord = [SELECT ID, Intent__c, Intent_Confidence__c, Sentiment__c, Sentiment_Confidence__c, Aggregated_Sentiment__c, Position__c, CreatedDate FROM Einstein_Insight__c WHERE Voice_Call__c =:recordId ORDER BY CreatedDate DESC LIMIT 1];
            } else if (channelType == 'Chat'){
                eiRecord = [SELECT ID, Intent__c, Intent_Confidence__c, Sentiment__c, Sentiment_Confidence__c, Aggregated_Sentiment__c, Position__c, CreatedDate FROM Einstein_Insight__c WHERE Chat_Transcript__c =:recordId ORDER BY CreatedDate DESC LIMIT 1];
            } else if (channelType == 'Messaging'){
                eiRecord = [SELECT ID, Intent__c, Intent_Confidence__c, Sentiment__c, Sentiment_Confidence__c, Aggregated_Sentiment__c, Position__c, CreatedDate FROM Einstein_Insight__c WHERE Messaging_Session__c =:recordId ORDER BY CreatedDate DESC LIMIT 1];
            }
        } catch (System.QueryException qe){
            eiRecord.Aggregated_Sentiment__c = 0;
            eiRecord.Sentiment__c = 'neutral'; // no intent
            eiRecord.Sentiment_Confidence__c = 0.0;
            eiRecord.Intent__c = 'Unclassified meaning'; // no intent
            eiRecord.Intent_Confidence__c = 0.0;
        }
        
        return eiRecord;
    }
    
    @AuraEnabled
    public static Einstein_Insight__c generateEinsteinInsights(String transcriptText, String channelType, String recordId, Integer aggregatedSentiment){
        System.debug('Inputs were ' + transcriptText + ' ' + channelType + ' ' + recordId + ' ' + aggregatedSentiment);
        // get settings
        ConversationTKEinsteinConfig__c einsteinModelSettings = ConversationTKEinsteinConfig__c.getValues('Default');
        System.debug(einsteinModelSettings);
        String intentModel = (einsteinModelSettings != null && einsteinModelSettings.Intent_Model_Id__c != null) ? einsteinModelSettings.Intent_Model_Id__c : 'O5F46QIAFVWW3EGWLCZCNVIVIU';
        String sentimentModel = (einsteinModelSettings != null && einsteinModelSettings.Sentiment_Model_Id_1__c != null) ? einsteinModelSettings.Sentiment_Model_Id_1__c : 'CommunitySentiment';
        //Get Einstein Intent
        einsteinplay.Einstein_PredictionService serviceIntent = new einsteinplay.Einstein_PredictionService(einsteinplay.Einstein_PredictionService.Types.INTENT);
        einsteinplay.Einstein_PredictionResult predictionIntent = serviceIntent.predictIntent(intentModel, transcriptText, 3, '');
        //Get Einstein Sentiment
        einsteinplay.Einstein_PredictionService serviceSentiment = new einsteinplay.Einstein_PredictionService(einsteinplay.Einstein_PredictionService.Types.SENTIMENT);
        einsteinplay.Einstein_PredictionResult predictionSentiment = serviceSentiment.predictSentiment(sentimentModel, transcriptText, 3, '');
        //Save data to Einstein Insight object
        Einstein_Insight__c insight = new Einstein_Insight__c();
        insight.Name = transcriptText;
        insight.Intent__c = predictionIntent.probabilities[0].label;
        insight.Intent_Confidence__c = predictionIntent.probabilities[0].probability;
        System.debug('Intent is '+ insight.Intent__c + ' ' + insight.Intent_Confidence__c);
        insight.Sentiment__c = predictionSentiment.probabilities[0].label;
        insight.Sentiment_Confidence__c = predictionSentiment.probabilities[0].probability;
        System.debug('Sentiment is ' + insight.Sentiment__c + ' ' + insight.Sentiment_Confidence__c);
        if (insight.Sentiment__c == 'Positive'){
            aggregatedSentiment++;
        } else if (insight.Sentiment__c == 'Negative'){
            aggregatedSentiment--;
        }
        insight.Aggregated_Sentiment__c = aggregatedSentiment;
        System.debug('Aggregated Sentiment is ' + aggregatedSentiment);
        //Check Service Channel
        if (channelType == 'Voice'){
            insight.Voice_Call__c = recordId;
        } else if (channelType == 'Chat'){
            insight.Chat_Transcript__c = recordId;
        } else if (channelType == 'Messaging'){
            insight.Messaging_Session__c = recordId;
        }
        insert insight;
        
        return insight;
    }
}
