#!/bin/ash
TC_HOME_DIR=/home/deploy/team-city
. ${TC_HOME_DIR}/.env
LOG_FILE="${TC_HOME_DIR}/TC_upgrade.log"
#token_teamcity = should be sourced from .env file
VERSION_CURRENT=$(curl -H "Authorization: Bearer $token_teamcity" -H "Content-Type: application/xml"  -X GET  http://localhost:8111/admin/admin.html?item=update 2>/dev/null   | egrep -io  ".{0,10}\(build.{0,8}" | tail -n 1 )
IS_NEW_VERSION=$(curl -H "Authorization: Bearer $token_teamcity" -H "Content-Type: application/xml"  -X GET  http://localhost:8111/admin/admin.html?item=update 2>/dev/null   | egrep -io  "updateOptionsContainer")
VERSION_NEW=$(curl -H "Authorization: Bearer $token_teamcity" -H "Content-Type: application/xml"  -X GET  http://localhost:8111/admin/admin.html?item=update 2>/dev/null   | egrep -io -m 1 ".{0,10}\(build.{0,8}") 
MESSAGE="The TeamCity version: $VERSION_CURRENT has been successfully upgraded to version: $VERSION_NEW"
exec >> $LOG_FILE 2>&1

# Check if new version is available:
if [[ ! $IS_NEW_VERSION ]] 
    then
	# If not available, report current version to log file:
        echo -e "\e[91m$(date +%d-%m-%Y_%H:%M:%S)\e[0m \e[93mCurrent TeamCity version is: $VERSION_CURRENT. No update available.\e[0m"
	exit 0
    else
	# If there is, start pulling new version in background:
	docker pull jetbrains/teamcity-server:latest && \ 
	echo $(date +%d-%m-%Y_%H-%M-%S)
	echo -e "\e[0m \e[93mCurrent TeamCity version is: $VERSION_CURRENT\e[0m"
	echo -e "\e[0m \e[43mNew TeamCity version is: $VERSION_NEW\e[0m"
	/usr/bin/telegram-send.sh "TeamCity upgrade started..." >/dev/null
	# Restart docker-compose with new TC-image (lastest):
	cd $TC_HOME_DIR && \
            docker-compose stop TeamCity-Server && \
	    docker rm $(docker ps -aq  --filter ancestor="jetbrains/teamcity-server") && \
	    docker rmi $(docker images jetbrains/teamcity-server -q) && \
	    docker-compose up -d && \
        # Send TC upgrade completeion report to Telegram:
	    /usr/bin/telegram-send.sh "${MESSAGE}" >/dev/null
        # Get authentication token from Log file to unlcok Team-City after upgrade: 
	tc_unlock_token=$(grep -Eo '\d{19}' ${TC_HOME_DIR}/server/logs/teamcity-server.log | tail -n 1) 
	# Send unlock token to Telegram:
	/usr/bin/telegram-send.sh "Super user authentication token: ${tc_unlock_token}"
        exit 0
fi
exit 0
