#!/bin/bash

# Bright Foreground Colors
BLACK_TEXT=$'\033[0;90m'
RED_TEXT=$'\033[0;91m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
BLUE_TEXT=$'\033[0;94m'
MAGENTA_TEXT=$'\033[0;95m'
CYAN_TEXT=$'\033[0;96m'
WHITE_TEXT=$'\033[0;97m'

NO_COLOR=$'\033[0m'
RESET_FORMAT=$'\033[0m'
BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

gcloud services disable dataflow.googleapis.com

gcloud services enable dataflow.googleapis.com

bq mk taxirides

bq mk \
--time_partitioning_field timestamp \
--schema ride_id:string,point_idx:integer,latitude:float,longitude:float,\
timestamp:timestamp,meter_reading:float,meter_increment:float,ride_status:string,\
passenger_count:integer -t taxirides.realtime

gsutil mb gs://$DEVSHELL_PROJECT_ID/

sleep 45

check_job_status() {
    while true; do
        JOB_STATUS=$(gcloud dataflow jobs list --region "$REGION" --filter="name=iotflow" --format="value(state)")
        
        if [[ "$JOB_STATUS" == "Running" ]]; then
            echo "${GREEN_TEXT}${BOLD_TEXT} Dataflow job is running successfully! ${RESET_FORMAT}"
            return 0
        elif [[ "$JOB_STATUS" == "Failed" || "$JOB_STATUS" == "Cancelled" ]]; then
            echo "${RED_TEXT}${BOLD_TEXT} Dataflow job failed! Retrying... ${RESET_FORMAT}"
            return 1
        fi
        
        echo "Waiting for job to complete..."
        sleep 20
    done
}

run_dataflow_job() {
    echo
    echo "${GREEN_TEXT}${BOLD_TEXT} ========================== Running Dataflow Job ========================== ${RESET_FORMAT}"
    echo

    JOB_ID=$(gcloud dataflow jobs run iotflow \
    --gcs-location gs://dataflow-templates/latest/PubSub_to_BigQuery \
    --region "$REGION" \
    --staging-location gs://$DEVSHELL_PROJECT_ID/temp \
    --parameters inputTopic=projects/pubsub-public-data/topics/taxirides-realtime,outputTableSpec=$DEVSHELL_PROJECT_ID:taxirides.realtime \
    --format="value(id)")

    echo "Dataflow Job ID: $JOB_ID"
    sleep 30  # Give it some time to start
}

# Run job and check status in a loop
while true; do
    run_dataflow_job
    check_job_status

    if [[ $? -eq 0 ]]; then
        break
    else
        echo "${YELLOW_TEXT}${BOLD_TEXT} Deleting failed Dataflow job... ${RESET_FORMAT}"
        gcloud dataflow jobs cancel iotflow --region "$REGION"
        echo "${YELLOW_TEXT}${BOLD_TEXT} Retrying Dataflow job... ${RESET_FORMAT}"
        sleep 10
    fi
done
echo
