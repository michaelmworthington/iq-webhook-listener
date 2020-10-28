#!/bin/sh

#Sample 
# Headers: {
#     "x-csrf-token": "CSRF-REQUEST-TOKEN",
#     "accept-encoding": "gzip,deflate",
#     "connection": "Close",
#     "x-nexus-webhook-id": "iq:applicationEvaluation",
#     "x-nexus-webhook-delivery": "8f780689-b6be-4a40-a233-bd35e1edc924",
#     "content-length": "633",
#     "content-type": "application/json; charset=UTF-8",
#     "host": "host.docker.internal:2001",
#     "user-agent": "Sonatype_CLM_Server/1.100.0-01 (Java 1.8.0_265; Linux 4.19.76-linuxkit) ",
#     "cookie": "CLM-CSRF-TOKEN=CSRF-REQUEST-TOKEN"
# }
# Body: {
#     "timestamp": "2020-10-28T15:08:32.348+0000",
#     "initiator": "admin",
#     "id": "c958957577cf4d7f9262f07ddebf5e1d",
#     "applicationEvaluation": {
#         "application": {
#             "id": "105289f286e94aa5968248f10a155cc2",
#             "publicId": "scanIQ",
#             "name": "scanIQ",
#             "organizationId": "2d0dfb87b67b43a3b4271e462bae9eca"
#         },
#         "policyEvaluationId": "c958957577cf4d7f9262f07ddebf5e1d",
#         "stage": "release",
#         "ownerId": "105289f286e94aa5968248f10a155cc2",
#         "evaluationDate": "2020-10-28T15:08:31.519+0000",
#         "affectedComponentCount": 9,
#         "criticalComponentCount": 5,
#         "severeComponentCount": 3,
#         "moderateComponentCount": 1,
#         "outcome": "fail",
#         "reportId": "ee158dd0a2ed49018720dbbafd19dc63",
#         "isForLatestScan": true
#     }
#}

DEP_TRACK_BASE_URL=http://host.docker.internal:8050
DEP_TRACK_API_KEY=cQ2iml4UTWAMF1PR1u49v3Iq28cuhK90 #(for the "automation" user)
IQ_BASE_URL=http://host.docker.internal:8060/iq
IQ_AUTH=YWRtaW46YWRtaW4xMjM= #(admin:admin123)


echo "******* post-iq-scan-to-deptrack *******"

# Debugging Stuff 
echo "~~~~~~~~~~~~~~~~~Payload~~~~~~~~~~~~~~~~~"
echo $1 # Entire Payload
echo "~~~~~~~~~~~~~~~~~Header~~~~~~~~~~~~~~~~~"
echo $2 # Entire Headers
echo "~~~~~~~~~~~~~~~~~Header: IQ WebHook ID~~~~~~~~~~~~~~~~~"
echo $3 # IQ Webhook ID
echo "~~~~~~~~~~~~~~~~~Payload: App Public ID~~~~~~~~~~~~~~~~~"
echo $4 # App Public Id
echo "~~~~~~~~~~~~~~~~~Payload: App Internal ID~~~~~~~~~~~~~~~~~"
echo $5 # App Internal Id
echo "~~~~~~~~~~~~~~~~~Payload: Eval Stage~~~~~~~~~~~~~~~~~"
echo $6 # Eval Stage
echo "~~~~~~~~~~~~~~~~~Payload: Eval Report ID~~~~~~~~~~~~~~~~~"
echo $7 # Report ID

P_IQ_WEBHOOK_ID=$3
P_APP_NAME=$4
P_APP_ID=$5
P_EVAL_STAGE=$6
P_EVAL_REPORT_ID=$7
                                                
#########################################################
#   0. validate this is the right webhook event type
#########################################################
if [ "$P_IQ_WEBHOOK_ID" != "iq:applicationEvaluation" ]
then                                                          
  echo "Skipping Processing Webhook: $P_IQ_WEBHOOK_ID"
  exit 0                                                  
fi                

#########################################################
#   1. get IQ CycloneDX SBOM
#########################################################
SBOM=`curl -s --request GET "$IQ_BASE_URL/api/v2/cycloneDx/$P_APP_ID/reports/$P_EVAL_REPORT_ID" --header "Authorization: Basic $IQ_AUTH"`

#########################################################
#   2. Create or Lookup Dep Track Project Id
#########################################################

#DTA=`curl "$DEP_TRACK_BASE_URL/api/v1/project/lookup?name=$P_APP_NAME&version=$P_EVAL_STAGE" --header "X-Api-Key: $DEP_TRACK_API_KEY"`
                 
#echo "DTA Response:"                           
#echo "$DTA"            
                                               
RC_DEP_TRACK_APP=`curl -s -o /dev/null -I -w "%{http_code}" --request GET "$DEP_TRACK_BASE_URL/api/v1/project/lookup?name=$P_APP_NAME&version=$P_EVAL_STAGE" --header "X-Api-Key: $DEP_TRACK_API_KEY"`
                                                              
#echo "Dep Track App Exists: $RC_DEP_TRACK_APP"

if [ "$RC_DEP_TRACK_APP" == "200" ]
then
	#echo "APP EXISTS!!"
    DEP_TRACK_APP_ID=`curl -s --request GET "$DEP_TRACK_BASE_URL/api/v1/project/lookup?name=$P_APP_NAME&version=$P_EVAL_STAGE" --header "X-Api-Key: $DEP_TRACK_API_KEY" | jq -r .uuid`

elif [ "$RC_DEP_TRACK_APP" == "404" ]
then
	#echo "APP DOES NOT EXIST. CREATING IT."
    DEP_TRACK_APP_ID=`curl -s --request PUT "$DEP_TRACK_BASE_URL/api/v1/project" --header "X-Api-Key: $DEP_TRACK_API_KEY" --header "Content-Type: application/json" --data-raw "{\"name\": \"$P_APP_NAME\", \"version\": \"$P_EVAL_STAGE\", \"active\": true}" | jq -r .uuid`
                                                              
else
	echo "ERROR: SOMETHING ELSE HAPPENED: $RC_DEP_TRACK_APP"
fi
                                                              
echo "~~~~~~~~~~~~~~~~~Dep Track App ID~~~~~~~~~~~~~~~~~"
echo "$DEP_TRACK_APP_ID"

#########################################################
#   3. Post the SBOM to Dep Track
#########################################################

#remove whitespace from the xml string before encoding it (nevermind)
#SBOM_64=`echo $SBOM | tr -d '[:space:]' | base64`

#base64 on alpine wraps the output. need to remove those newlines
SBOM_64=`echo $SBOM | base64 | tr -d '\n'`
#SBOM_64=""

#curl -s --request POST "$DEP_TRACK_BASE_URL/api/v1/bom" \
#--header "X-Api-Key: $DEP_TRACK_API_KEY" \
#--form "project=$DEP_TRACK_APP_ID" \
#--form "bom=$SBOM"

echo "~~~~~~~~~~~~~~~~~Dep Track SBOM Token~~~~~~~~~~~~~~~~~"
curl -s --request PUT "$DEP_TRACK_BASE_URL/api/v1/bom" --header "X-Api-Key: $DEP_TRACK_API_KEY" --header "Content-Type: application/json" --data-raw "{\"project\": \"$DEP_TRACK_APP_ID\", \"bom\": \"$SBOM_64\"}"

echo ""
echo "Dep Track BOM RC: $?"
