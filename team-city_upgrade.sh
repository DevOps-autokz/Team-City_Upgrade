#!/bin/sh
SCRIPT_HOME="$HOME/scripts"
TEAMCITY_HOME="$HOME/team-city"
[ -f ${SCRIPT_HOME}/.env ] && . ${SCRIPT_HOME}/.env
TEAMCITY_URL="http://localhost:8111"
LOG_FILE="${SCRIPT_HOME}/team-city_upgrade.log"
#token_teamcity="insert your TeamCity token here, or to .env file"
VERSION_CURRENT=$(curl -H "Authorization: Bearer $token_teamcity" -H "Content-Type: application/xml"  -X GET "$TEAMCITY_URL/admin/admin.html?item=update" 2>/dev/null | grep -Eio -m 1  ".{0,10}\(build.{0,8}")
IS_NEW_VERSION=$(curl -H "Authorization: Bearer $token_teamcity" -H "Content-Type: application/xml"  -X GET  "$TEAMCITY_URL/admin/admin.html?item=update" 2>/dev/null | grep -Eio  "updateOptionsContainer")
VERSION_NEW=$(curl -H "Authorization: Bearer $token_teamcity" -H "Content-Type: application/xml"  -X GET "$TEAMCITY_URL/admin/admin.html?item=update" 2>/dev/null | grep -Eio -m 2 ".{0,10}\(build.{0,8}" | tail -n 1) 
IMAGE_ID_CURRENT=$(docker images -q "jetbrains/teamcity-server")
#TG_TOKEN_ADMIN="insert your Telegram Admin Chat-ID here, or to .env file"
#TG_TOKEN_GROUP="insert your Telegram Group Chat-ID here, or to .env file"
MESSAGE="The TeamCity version: $VERSION_CURRENT has been successfully upgraded to version: $VERSION_NEW"
exec >> $LOG_FILE 2>&1

# Check if new version is available:
if [[ $IS_NEW_VERSION ]] 
    then
	# If there is, report upgrade starting to log-file and Telegram:
	echo -e "\e[31m$(date '+%d-%m-%Y %H-%M-%S')\e[0m"
	echo -e "\e[33mCurrent TeamCity version is: $VERSION_CURRENT\e[0m"
	echo -e "\e[32mNew TeamCity version is: $VERSION_NEW\e[0m"
	/usr/bin/telegram-send "TeamCity upgrade started..." >/dev/null
	# start pulling new version in background:
	docker pull -q jetbrains/teamcity-server:latest && \

	# Restart docker-compose with new TC-image (lastest):
	cd "${TEAMCITY_HOME}" && \
	docker compose stop TeamCity-Server && \
	docker compose rm -f TeamCity-Server && \
	docker rmi $IMAGE_ID_CURRENT && \
	docker compose up -d && \
	sleep 5

        # Get authentication token from Log file to unlcok Team-City after upgrade: 
	tc_unlock_token=$(grep -Eo '\d{19}' ${TEAMCITY_HOME}/server/logs/teamcity-server.log | tail -n 1) 
	# Send unlock token to log-file and Telegram:
	echo -e "\e[36mSuper user authentication token: ${tc_unlock_token}\e[0m"
	/usr/bin/telegram-send "Super user authentication token: ${tc_unlock_token}" ${TG_TOKEN_ADMIN} >/dev/null

	# Report upgrade completion to log-file and Telegram:
	echo -e "\e[32mTeam-City successfully upgraded to version: $VERSION_NEW\e[0m" && \
	echo -e "\e[33m------------------------------------------------ \e[0m"
	/usr/bin/telegram-send "${MESSAGE}" ${TG_TOKEN_GROUP} >/dev/null
fi
exit 0
