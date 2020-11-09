public with sharing class InvocableBotLanguage {
    public InvocableBotLanguage() {

    }

    public class HandleInput {
        @InvocableVariable(required=false)
        public String sCurrentUtterance;
        @InvocableVariable(required=false)
        public String sLiveChatTranscriptId;
        @InvocableVariable(required=false)
        public Double dConfidenceThreshold;
        @InvocableVariable(required=false)
        public Integer iAggregatedSentiment;
    }
 
    public class HandleOutput {
        @InvocableVariable(required=false)
        public String sDetectedIntent;
        @InvocableVariable(required=false)
        public Double dDetectedIntentConfidence;

        @InvocableVariable(required=false)
        public String sDetectedSentiment;
        @InvocableVariable(required=false)
        public Double dDetectedSentimentConfidence;
        @InvocableVariable(required=false)
        public Integer iAggregatedSentiment;

        @InvocableVariable(required=false)
        public Boolean bHasPredictions;
    }

    // This is massively monolithic and needs refactoring
    @InvocableMethod(label='Einstein Intent and Sentiment Logger and Router')
    public static List<handleOutput> handleIntentDetectionFailure(List<HandleInput> inputParameters) {
        // Create default output values
        List<HandleOutput> outputParameters = new List<HandleOutput>();
        HandleOutput outputParameter = new HandleOutput();
        outputParameter.sDetectedIntent = ''; // nothing
        outputParameter.dDetectedIntentConfidence = 0.0; 
        outputParameter.sDetectedSentiment = 'Neutral'; 
        outputParameter.dDetectedSentimentConfidence = 0.0;
        outputParameter.iAggregatedSentiment = 0; 
        outputParameter.bHasPredictions = false; // until we run, assume this is blank text
        
        try{
            // check for important blanks or nulls.
            // bail out if they aren't present
            if (inputParameters == null || inputParameters[0].sCurrentUtterance == null || String.isBlank(inputParameters[0].sCurrentUtterance) ){
                outputParameters.add(outputParameter);       
                return outputParameters;
            }

            String sCurrentUtterance = inputParameters[0].sCurrentUtterance;
            String sLiveChatTranscriptId = inputParameters[0].sLiveChatTranscriptId;
            Double dConfidenceThreshold = inputParameters[0].dConfidenceThreshold;
            Integer iAggregatedSentiment = inputParameters[0].iAggregatedSentiment;
            if (dConfidenceThreshold == null){
                dConfidenceThreshold = 0.0;
            }
            if (iAggregatedSentiment == null){
                iAggregatedSentiment = 0;
            } 
            outputParameter.bHasPredictions = true; 
    
            
            
            
    
            System.debug('Inputs were [' + sCurrentUtterance + '], transcript id: ' + sLiveChatTranscriptId +  + ' confidence threshold: ' + dConfidenceThreshold + ' aggregated sentiment: ' + iAggregatedSentiment);
            // get settings
            ConversationTKEinsteinConfig__c einsteinModelSettings = ConversationTKEinsteinConfig__c.getValues('Default');
            System.debug(einsteinModelSettings);
            String intentModel = (einsteinModelSettings != null && einsteinModelSettings.Intent_Model_Id__c != null) ? einsteinModelSettings.Intent_Model_Id__c : 'O5F46QIAFVWW3EGWLCZCNVIVIU';
            String sentimentModel = (einsteinModelSettings != null && einsteinModelSettings.Sentiment_Model_Id_1__c != null) ? einsteinModelSettings.Sentiment_Model_Id_1__c : 'CommunitySentiment';

            //Get Einstein Intent
            einsteinplay.Einstein_PredictionService serviceIntent = new einsteinplay.Einstein_PredictionService(einsteinplay.Einstein_PredictionService.Types.INTENT);
            einsteinplay.Einstein_PredictionResult predictionIntent = serviceIntent.predictIntent(intentModel, sCurrentUtterance, 3, '');
            //Get Einstein Sentiment
            einsteinplay.Einstein_PredictionService serviceSentiment = new einsteinplay.Einstein_PredictionService(einsteinplay.Einstein_PredictionService.Types.SENTIMENT);
            einsteinplay.Einstein_PredictionResult predictionSentiment = serviceSentiment.predictSentiment(sentimentModel, sCurrentUtterance, 3, '');

            //Save data to Bot Utterance object
            Bot_Utterance__c utteranceLog = new Bot_Utterance__c();
            utteranceLog.Current_Utterance__c = sCurrentUtterance;
            utteranceLog.Intent_1__c = predictionIntent.probabilities[0].label;
            utteranceLog.Intent_Confidence_1__c = predictionIntent.probabilities[0].probability;
            System.debug('Intent is '+ utteranceLog.Intent_1__c + ' ' + utteranceLog.Intent_Confidence_1__c);
            utteranceLog.Sentiment__c = predictionSentiment.probabilities[0].label;
            utteranceLog.Sentiment_Confidence__c = predictionSentiment.probabilities[0].probability;
            System.debug('Sentiment is ' + utteranceLog.Sentiment__c + ' ' + utteranceLog.Sentiment_Confidence__c);
            if (utteranceLog.Sentiment__c == 'Positive'){
                iAggregatedSentiment++;
            } else if (utteranceLog.Sentiment__c == 'Negative'){
                iAggregatedSentiment--;
            }
            utteranceLog.Chat_Transcript__c = sLiveChatTranscriptId;
            utteranceLog.Utterance_Source__c = 'Customer';  // should never be the bot

            // utteranceLog.Aggregated_Sentiment__c = iAggregatedSentiment;

            // also log to Einstein_Insight__c
            Einstein_Insight__c insight = new Einstein_Insight__c();
            insight.Chat_Transcript__c = sLiveChatTranscriptId;
            insight.Name = sCurrentUtterance;
            insight.Intent__c = predictionIntent.probabilities[0].label;
            insight.Intent_Confidence__c = predictionIntent.probabilities[0].probability;
            System.debug('Intent is '+ insight.Intent__c + ' ' + insight.Intent_Confidence__c);
            insight.Sentiment__c = predictionSentiment.probabilities[0].label;
            insight.Sentiment_Confidence__c = predictionSentiment.probabilities[0].probability;
            System.debug('Sentiment is ' + insight.Sentiment__c + ' ' + insight.Sentiment_Confidence__c);
            
            insight.Aggregated_Sentiment__c = iAggregatedSentiment;
            
            
            System.debug('Aggregated Sentiment is ' + iAggregatedSentiment);
            
            // output params
            outputParameter.dDetectedIntentConfidence = utteranceLog.Intent_Confidence_1__c; 
            if (outputParameter.dDetectedIntentConfidence >= dConfidenceThreshold){
                outputParameter.sDetectedIntent = utteranceLog.Intent_1__c;
            } // else default
            outputParameter.dDetectedSentimentConfidence = utteranceLog.Sentiment_Confidence__c;
            if (outputParameter.dDetectedSentimentConfidence >= dConfidenceThreshold){
                outputParameter.sDetectedSentiment = utteranceLog.Sentiment__c;
            }
            outputParameter.iAggregatedSentiment = iAggregatedSentiment;

            // Lagniappe--link to the case if it's possible
            try{
                LiveChatTranscript lct = [SELECT Id, Name, CaseID, Channel_Name__c, CreatedDate FROM LiveChatTranscript WHERE ID = :sLiveChatTranscriptId];
                if (lct != null && lct.CaseId != null){
                    utteranceLog.Case__c = lct.CaseId;
                    insight.Case__c = lct.CaseId;
                }
            } catch (Exception e1){
                //TODO
                System.debug(e1.getStackTraceString());
            }
            insert utteranceLog;
            insert insight;
        } catch(Exception ex){
            System.debug(ex.getStackTraceString());
        }
        outputParameters.add(outputParameter);       
        return outputParameters;
    }
}

