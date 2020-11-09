public with sharing class EinsteinInsight {
    // public attributes
    @AuraEnabled public String PredictedIntent {get; set;}
    @AuraEnabled public Double PredictedIntentConfidence {get; set;}
    @AuraEnabled public String PredictedSentiment {get; set;}
    @AuraEnabled public Double PredictedSentimentConfidence {get; set;}
    @AuraEnabled public Integer AggregatedSentiment {get; set;}

    // Default, no-arg constructor, for client-side -> server-side
    public EinsteinInsight() {

    }
    // Trivial constructor, for server-side Apex -> client-side JavaScript
    public EinsteinInsight(String intent, Double intentConfidence, String sentiment, Double sentimentConfidence, Integer aggregatedSentiment){
        this.PredictedIntent = intent;
        this.PredictedIntentConfidence = intentConfidence;
        this.PredictedSentiment = sentiment;
        this.PredictedSentimentConfidence = sentimentConfidence;
        this.AggregatedSentiment = aggregatedSentiment;
    }
}
