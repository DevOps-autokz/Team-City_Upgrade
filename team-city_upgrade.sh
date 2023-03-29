#!/bin/bash
SCRIPT_HOME="$HOME/scripts/team-city_upgrade"
TEAMCITY_HOME="$HOME/team-city"
. ${SCRIPT_HOME}/.env
TEAMCITY_URL="http://localhost:8111"
LOG_FILE="${TEAMCITY_HOME}/team-city_upgrade.log"
#token_teamcity = should be sourced from .env file
VERSION_CURRENT=$(curl -H "Authorization: Bearer $token_teamcity" -H "Content-Type: application/xml"  -X GET "$TEAMCITY_URL/admin/admin.html?item=update" 2>/dev/null | grep -Eio  ".{0,10}\(build.{0,8}" | tail -n 1 )
IS_NEW_VERSION=$(curl -H "Authorization: Bearer $token_teamcity" -H "Content-Type: application/xml"  -X GET  "$TEAMCITY_URL/admin/admin.html?item=update" 2>/dev/null | grep -Eio  "updateOptionsContainer")
VERSION_NEW=$(curl -H "Authorization: Bearer $token_teamcity" -H "Content-Type: application/xml"  -X GET "$TEAMCITY_URL/admin/admin.html?item=update" 2>/dev/null | grep -Eio -m 1 ".{0,10}\(build.{0,8}") 
IMAGE_ID_CURRENT=$(docker images -q "jetbrains/teamcity-server")
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
	echo -e "\e[31m$(date '+%d-%m-%Y %H-%M-%S')\e[0m"
	echo -e "\e[33mCurrent TeamCity version is: $VERSION_CURRENT\e[0m"
	echo -e "\e[32mNew TeamCity version is: $VERSION_NEW\e[0m"
	/usr/bin/telegram-send "TeamCity upgrade started..." >/dev/null

	# Restart docker-compose with new TC-image (lastest):
	cd "${TEAMCITY_HOME}" && \
	docker compose stop TeamCity-Server && \
	docker compose rm -f TeamCity-Server && \
	docker rmi $IMAGE_ID_CURRENT && \
	docker compose up -d && \

        # Get authentication token from Log file to unlcok Team-City after upgrade: 
	tc_unlock_token=$(grep -Eo '\d{19}' ${TEAMCITY_HOME}/server/logs/teamcity-server.log | tail -n 1) 
	# Send unlock token to log-file and Telegram:
	echo -e "\e[36mSuper user authentication token: ${tc_unlock_token}\e[0m"
	/usr/bin/telegram-send "Super user authentication token: ${tc_unlock_token}"

	# Report upgrade completion to log-file and Telegram:
	echo -e "\e[32mTeam-City successfully upgraded to version: $VERSION_NEW\e[0m" && \
	echo -e "\e[33m------------------------------------------------ \e[0m"
	/usr/bin/telegram-send "${MESSAGE}" >/dev/null
fi
exit 0